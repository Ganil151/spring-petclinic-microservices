output "secret_arn" {
  description = "Database credentials secret ARN"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "openai_secret_arn" {
  description = "OpenAI API key secret ARN"
  value       = var.openai_api_key != "" ? aws_secretsmanager_secret.openai_key[0].arn : ""
}
