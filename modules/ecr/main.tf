locals {
  repositories = [
    "blume-backend",
    "stream-engine",
    "record-service",
    "blume-wa",
    "activities-ms",
    "recommendations-ms",
    "blume-mediamtx",
  ]
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(local.repositories)
  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Project = var.project }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 10 sha-tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Keep latest tag"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = { type = "expire" }
      }
    ]
  })
}
