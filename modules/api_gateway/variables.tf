variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the VPC Link"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID attached to the internal ALB"
  type        = string
}

variable "alb_listener_arn" {
  description = "ARN of the ALB HTTP listener (port 80)"
  type        = string
}
