variable "project" {
  description = "Project name prefix"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "blume"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "Security group ID for RDS"
  type        = string
}
