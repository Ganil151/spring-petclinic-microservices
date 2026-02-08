#!/bin/bash
set -e

ENV=$1
if [ -z "$ENV" ]; then
  echo "Usage: ./apply.sh <environment>"
  echo "Example: ./apply.sh dev"
  exit 1
fi

cd "$(dirname "$0")/../environments/$ENV"

if [ ! -f "tfplan" ]; then
  echo "❌ No plan file found. Run ./plan.sh $ENV first"
  exit 1
fi

echo "Applying Terraform plan for $ENV environment..."
terraform apply tfplan

rm -f tfplan

echo "✅ Infrastructure deployed successfully"
