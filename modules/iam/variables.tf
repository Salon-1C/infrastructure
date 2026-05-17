variable "project" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repos" {
  description = "GitHub repository names allowed to assume the deploy role"
  type        = list(string)
}

variable "ecr_repository_names" {
  description = "ECR repository names GitHub Actions may push to"
  type        = list(string)
}

variable "recordings_bucket_arn" {
  type = string
}
