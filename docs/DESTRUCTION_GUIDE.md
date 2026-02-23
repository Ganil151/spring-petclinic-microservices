# 🔥 Complete Project Destruction Guide

**Purpose:** Fully destroy all infrastructure and start fresh  
**Last Updated:** February 22, 2026

---

## ⚠️ CRITICAL WARNINGS

**BEFORE PROCEEDING:**

1. **This is PERMANENT** - All data will be lost forever
2. **Backup important data** - Export databases, secrets, configurations
3. **Notify team members** - Ensure no one is using the infrastructure
4. **Check costs** - Verify all resources are tagged for deletion
5. **Document current state** - Save IP addresses, endpoints, credentials

---

## 📋 Pre-Destruction Checklist

- [ ] Backed up RDS database (if needed)
- [ ] Exported all secrets from AWS Secrets Manager / SSM
- [ ] Saved Jenkins configurations and jobs
- [ ] Exported SonarQube analysis data
- [ ] Downloaded SSH private keys
- [ ] Notified all team members
- [ ] Verified no critical processes are running
- [ ] Have AWS credentials with delete permissions

---

## 🚀 Method 1: Quick Destroy (Recommended)

### Step 1: Destroy All Terraform Resources

```bash
cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/live/dev

# Destroy everything in correct order (respects dependencies)
terragrunt run --all destroy -auto-approve
```

### Step 2: Delete S3 State Buckets

```bash
# Dev bucket
aws s3 rb s3://petclinic-state-dev-a7f3c2 --force

# Staging bucket
aws s3 rb s3://petclinic-state-staging-b9d4e1 --force

# Production bucket (⚠️ Be very careful!)
aws s3 rb s3://petclinic-state-365269738775 --force
```

### Step 3: Delete DynamoDB Table

```bash
aws dynamodb delete-table \
  --table-name terraform-lock-table \
  --region us-east-1
```

### Step 4: Clean Up Remaining AWS Resources

```bash
# Delete remaining EC2 instances
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=spring-petclinic" \
  --query "Reservations[].Instances[].InstanceId" \
  --output text | xargs -n1 aws ec2 terminate-instances --instance-ids 2>/dev/null || true

# Delete remaining security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=spring-petclinic" \
  --query "SecurityGroups[].GroupId" \
  --output text | xargs -n1 aws ec2 delete-security-group --group-id 2>/dev/null || true

# Delete remaining key pairs
aws ec2 describe-key-pairs \
  --filters "Name=tag:Key,Values=Project" \
  --query "KeyPairs[].KeyPairId" \
  --output text | xargs -n1 aws ec2 delete-key-pair --key-pair-id 2>/dev/null || true

# Delete EBS snapshots
aws ec2 describe-snapshots \
  --owner-ids self \
  --filters "Name=tag:Project,Values=spring-petclinic" \
  --query "Snapshots[].SnapshotId" \
  --output text | xargs -n1 aws ec2 delete-snapshot --snapshot-id 2>/dev/null || true
```

### Step 5: Delete SSM Parameters

```bash
# Database credentials
aws ssm delete-parameter --name "/spring-petclinic/dev/database/password" 2>/dev/null || true
aws ssm delete-parameter --name "/spring-petclinic/dev/database/username" 2>/dev/null || true
aws ssm delete-parameter --name "/spring-petclinic/dev/database/endpoint" 2>/dev/null || true

# SSH Key
aws ssm delete-parameter --name "/spring-petclinic/dev/key-pair/spms-dev" 2>/dev/null || true
```

### Step 6: Delete CloudWatch Log Groups

```bash
aws logs delete-log-group --log-group-name "/spring-petclinic/dev/bastion" 2>/dev/null || true
aws logs delete-log-group --log-group-name "/spring-petclinic/dev/jenkins" 2>/dev/null || true
aws logs delete-log-group --log-group-name "/spring-petclinic/dev/sonarqube" 2>/dev/null || true
aws logs delete-log-group --log-group-name "/spring-petclinic/dev/workers" 2>/dev/null || true
```

### Step 7: Clean Up Local Files

```bash
cd /home/gsmash/Documents/spring-petclinic-microservices/terraform

# Remove Terragrunt cache
find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null

# Remove Terraform directories
find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null

# Remove lock files
find . -name ".terraform.lock.hcl" -delete 2>/dev/null

# Remove generated files
find . -name "backend.tf" -delete 2>/dev/null
find . -name "provider.tf" -delete 2>/dev/null
find . -name "versions" -delete 2>/dev/null

# Remove SSH key files
rm -f /home/gsmash/Documents/spring-petclinic-microservices/terraform/live/dev/key-pair/spms-dev.pem

# Remove Ansible inventory
rm -f /home/gsmash/Documents/spring-petclinic-microservices/ansible/inventory/hosts
```

---

## 🚀 Method 2: Manual Step-by-Step Destroy

**Use this if Method 1 fails or you need more control**

### Reverse Deployment Order

```bash
cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/live/dev

# 1. Destroy Ansible Inventory
cd ansible
terragrunt destroy -auto-approve
cd ..

# 2. Destroy ALB
cd alb
terragrunt destroy -auto-approve
cd ..

# 3. Destroy RDS Database (⚠️ DATA LOSS)
cd rds
terragrunt destroy -auto-approve
cd ..

# 4. Destroy EC2 Instances
cd ec2-instances
terragrunt destroy -auto-approve
cd ..

# 5. Destroy Security Groups
cd bastion
terragrunt destroy -auto-approve
cd ..

# 6. Destroy Key Pair
cd key-pair
terragrunt destroy -auto-approve
cd ..

# 7. Destroy VPC (MUST BE LAST)
cd vpc
terragrunt destroy -auto-approve
cd ..
```

Then continue with Steps 2-7 from Method 1.

---

## ✅ Verification

### Verify AWS Resources Are Deleted

```bash
# Check for EC2 instances (should be empty)
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=spring-petclinic" \
  --query "Reservations[].Instances[].InstanceId"

# Check for security groups (should be empty)
aws ec2 describe-security-groups \
  --filters "Name=tag:Project,Values=spring-petclinic" \
  --query "SecurityGroups[].GroupId"

# Check for key pairs (should be empty)
aws ec2 describe-key-pairs \
  --filters "Name=tag:Project,Values=spring-petclinic" \
  --query "KeyPairs[].KeyName"

# Check for S3 buckets (should not exist)
aws s3 ls | grep petclinic

# Check for DynamoDB tables (should not exist)
aws dynamodb list-tables --query "TableNames[?contains(@, 'terraform')]"

# Check for SSM parameters (should be empty)
aws ssm get-parameters-by-path \
  --path "/spring-petclinic/dev" \
  --query "Parameters[].Name"
```

**All commands should return empty results or errors indicating resources don't exist.**

---

## 🔄 Starting Fresh

After complete destruction, to start over:

### 1. Recreate S3 Buckets

```bash
REGION="us-east-1"

# Dev bucket
DEV_BUCKET="petclinic-state-dev-a7f3c2"
aws s3 mb s3://${DEV_BUCKET} --region ${REGION}
aws s3api put-bucket-versioning --bucket ${DEV_BUCKET} --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ${DEV_BUCKET} \
  --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
aws s3api put-public-access-block --bucket ${DEV_BUCKET} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Staging bucket
STAGING_BUCKET="petclinic-state-staging-b9d4e1"
aws s3 mb s3://${STAGING_BUCKET} --region ${REGION}
aws s3api put-bucket-versioning --bucket ${STAGING_BUCKET} --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ${STAGING_BUCKET} \
  --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
aws s3api put-public-access-block --bucket ${STAGING_BUCKET} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Production bucket
PROD_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROD_BUCKET="petclinic-state-${PROD_ACCOUNT_ID}"
aws s3 mb s3://${PROD_BUCKET} --region ${REGION}
aws s3api put-bucket-versioning --bucket ${PROD_BUCKET} --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket ${PROD_BUCKET} \
  --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
aws s3api put-public-access-block --bucket ${PROD_BUCKET} \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✓ Dev bucket: ${DEV_BUCKET}"
echo "✓ Staging bucket: ${STAGING_BUCKET}"
echo "✓ Prod bucket: ${PROD_BUCKET}"
```

### 2. Recreate DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

echo "✓ DynamoDB table created"
```

### 3. Start Fresh Deployment

```bash
cd /home/gsmash/Documents/spring-petclinic-microservices/terraform/live/dev

# Deploy in order
cd vpc && terragrunt init && terragrunt apply -auto-approve
cd ../key-pair && terragrunt init && terragrunt apply -auto-approve
cd ../bastion && terragrunt init && terragrunt apply -auto-approve
cd ../ec2-instances && terragrunt init && terragrunt apply -auto-approve
cd ../rds && terragrunt init && terragrunt apply -auto-approve
cd ../alb && terragrunt init && terragrunt apply -auto-approve
cd ../ansible && terragrunt init && terragrunt apply -auto-approve
```

---

## 🆘 Troubleshooting

### Issue: "BucketNotEmpty" when deleting S3

```bash
# Empty bucket first, then delete
aws s3 rb s3://bucket-name --force
```

### Issue: "DependencyViolation" when deleting security groups

```bash
# Find and delete dependent resources
aws ec2 describe-security-groups \
  --filters "Name=group-id,Values=sg-xxxxx" \
  --query "SecurityGroups[].IpPermissions[].UserIdGroupPairs[].GroupId"

# Delete the dependent security group first, then retry
```

### Issue: Terraform state locked

```bash
# Force unlock (use with caution!)
cd terraform/live/dev/<module>
terragrunt force-unlock LOCK_ID
```

### Issue: Resources stuck in "deleting" state

```bash
# Wait for eventual consistency (can take 10-30 minutes)
# Check status periodically
aws ec2 describe-instances --instance-ids i-xxxxx --query "Reservations[0].Instances[0].State"
```

---

## 📊 Cost Impact

**Resources that incur costs if not deleted:**

| Resource | Approx. Cost/Month | Priority |
|----------|-------------------|----------|
| RDS Database | $15-50 | 🔴 Critical |
| EC2 Instances | $10-30 each | 🔴 Critical |
| NAT Gateway | $32 + data transfer | 🔴 Critical |
| EBS Volumes | $0.10/GB | 🟡 High |
| S3 Buckets | $0.023/GB | 🟡 High |
| DynamoDB | $0.25/million RCU | 🟢 Low |
| CloudWatch Logs | $0.50/GB | 🟢 Low |

**Delete immediately to avoid unnecessary charges!**

---

## 📝 Post-Destruction Checklist

- [ ] All EC2 instances terminated
- [ ] All security groups deleted
- [ ] All key pairs deleted
- [ ] All S3 buckets emptied and deleted
- [ ] DynamoDB table deleted
- [ ] SSM parameters deleted
- [ ] CloudWatch log groups deleted
- [ ] Local Terraform cache cleaned
- [ ] Verified with AWS CLI (all commands return empty)
- [ ] Checked AWS Cost Explorer for remaining charges

---

## 📞 Support

If you encounter issues:

1. Check AWS Console for resource status
2. Review CloudTrail for API call history
3. Check Terraform state files for resource references
4. Consult AWS documentation for specific resource deletion

---

**Remember:** Always test destruction in a non-production environment first!
