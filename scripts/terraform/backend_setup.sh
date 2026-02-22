#!/bin/bash

# --- Configuration ---
# Check for AWS Identity
echo "Checking AWS Identity..."
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "CRITICAL ERROR: No AWS credentials found. Please run 'aws configure' or 'aws sso login' first."
    exit 1
fi

REGION="us-east-1"
ENV_PATH="/home/gsmash/Documents/spring-petclinic-microservices/terraform/backend.tf"
STATE_KEY="tfstate/dev/terraform.tfstate"

# --- Step 1: Create S3 Bucket (Storage Layer) ---
echo "--- Step 1: Creating S3 Bucket ---"
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="petclinic-terraform-state-${RANDOM_SUFFIX}"

if aws s3 mb s3://${BUCKET_NAME} --region ${REGION}; then
    echo "SUCCESS: Created ${BUCKET_NAME}"
else
    echo "ERROR: Failed to create bucket. It might already exist. Try running again."
    exit 1
fi

# --- Step 2: Enable Versioning (Durability Layer) ---
echo "--- Step 2: Enabling Versioning ---"
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# --- Step 3: Enable Server-Side Encryption (Security Layer) ---
echo "--- Step 3: Enabling Encryption ---"
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# --- Step 4: Block Public Access (Hardening Layer) ---
echo "--- Step 4: Blocking Public Access ---"
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# --- Step 5: Inject Configuration into backend.tf ---
echo "--- Step 5: Updating backend.tf ---"
mkdir -p ${ENV_PATH}

cat > ${ENV_PATH}/backend.tf << EOF
terraform {
  backend "s3" {
    bucket       = "${BUCKET_NAME}"
    key          = "${STATE_KEY}"
    region       = "${REGION}"
    use_lockfile = true
    encrypt      = true
  }
}
EOF

echo "--------------------------------------------------"
echo "SETUP COMPLETE"
echo "Bucket: ${BUCKET_NAME}"
echo "Location: ${ENV_PATH}/backend.tf"
echo "Next step: Run 'terraform init' in the dev directory."
echo "--------------------------------------------------"

# Optional: Save bucket name to a file for reference
echo ${BUCKET_NAME} > .terraform_bucket_name