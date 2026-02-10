# WAF Module

This module provisions an AWS WAFv2 Web ACL with managed rule sets for perimeter security.

## Features
- AWS Managed Rules for Common Vulnerabilities (OWASP Top 10).
- SQL Injection (SQLi) protection.
- CloudWatch metrics and sampled request logging.
- Regional scope (for use with ALB).

## Usage

```hcl
module "waf" {
  source = "../../modules/waf"

  project_name = "petclinic"
  environment  = "dev"
  scope        = "REGIONAL" # Use with ALB
}
```

After creating the WAF, attach it to your ALB:

```hcl
resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = module.alb.alb_arn
  web_acl_arn  = module.waf.web_acl_arn
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_name | Project name | `string` | n/a | yes |
| environment | Environment name | `string` | n/a | yes |
| scope | WAF scope | `string` | `REGIONAL` | no |

## Outputs

| Name | Description |
|------|-------------|
| web_acl_id | Web ACL ID |
| web_acl_arn | Web ACL ARN (for ALB association) |
| web_acl_capacity | WCU consumption |
