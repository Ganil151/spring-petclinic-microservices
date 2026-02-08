resource "aws_ecr_repository" "petclinic" {
  for_each = toset(var.repositories)

  name                 = "${var.environment}-petclinic-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.environment}-petclinic-${each.value}"
    Environment = var.environment
  }
}

resource "aws_ecr_lifecycle_policy" "petclinic" {
  for_each   = aws_ecr_repository.petclinic
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
