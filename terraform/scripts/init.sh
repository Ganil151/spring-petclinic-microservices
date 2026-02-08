#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: ./init.sh <environment>"
  echo "Example: ./init.sh dev"
  exit 1
fi

cd "$(dirname "$0")/../environments/$ENV"

echo "Initializing Terraform for $ENV environment..."
terraform init

echo "Validating configuration..."
terraform validate

echo "Formatting code..."
terraform fmt -recursive

echo "✅ Initialization complete for $ENV"
