resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.environment}/petclinic/db/credentials"
  description = "PetClinic database credentials"

  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    engine   = "mysql"
    host     = var.db_endpoint
    port     = 3306
    dbname   = var.db_name
  })
}

resource "aws_secretsmanager_secret" "openai_key" {
  count       = var.openai_api_key != "" ? 1 : 0
  name        = "${var.environment}/petclinic/openai/api-key"
  description = "OpenAI API key for GenAI service"

  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "openai_key" {
  count     = var.openai_api_key != "" ? 1 : 0
  secret_id = aws_secretsmanager_secret.openai_key[0].id
  secret_string = jsonencode({
    api_key = var.openai_api_key
  })
}
