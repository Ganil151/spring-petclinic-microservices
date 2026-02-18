resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = lower("${var.project_name}-${var.environment}-${each.value}")
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${each.value}"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Lifecycle policy to clean up old images (SRE standard)
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = toset(var.repository_names)
  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
