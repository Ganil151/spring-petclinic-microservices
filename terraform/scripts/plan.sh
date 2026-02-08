#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: ./plan.sh <environment>"
  echo "Example: ./plan.sh dev"
  exit 1
fi

cd "$(dirname "$0")/../environments/$ENV"

echo "Running Terraform plan for $ENV environment..."
terraform plan -out=tfplan

echo "✅ Plan saved to tfplan"
echo "Review the plan above. To apply, run: ./apply.sh $ENV"
