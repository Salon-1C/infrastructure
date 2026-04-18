variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name (e.g. Salon-1C)"
  type        = string
}

variable "github_repos" {
  description = "GitHub repository names that are allowed to assume the deploy role"
  type        = list(string)
  default     = ["business-logic", "stream-engine"]
}
