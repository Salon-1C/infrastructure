variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Short project name used as a prefix for all resource names"
  type        = string
  default     = "blume"
}

variable "environment" {
  description = "Environment name (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "github_org" {
  description = "GitHub organization that owns the Blume repositories"
  type        = string
}

# ── Database ──────────────────────────────────────────────────────────────────
variable "db_name" {
  type    = string
  default = "blume"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "recordings_db_name" {
  type    = string
  default = "recordings"
}

variable "recordings_db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "activities_db_name" {
  type    = string
  default = "stream_activities"
}

variable "activities_db_user" {
  type    = string
  default = "blume"
}

variable "activities_db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "recordings_bucket_name" {
  description = "Globally unique S3 bucket name for recorded videos"
  type        = string
}

# ── Application ───────────────────────────────────────────────────────────────
variable "public_app_url" {
  description = "Public HTTPS URL of the platform (e.g. https://app.example.com). Used for Next.js build args and Phoenix PHX_HOST."
  type        = string
}

variable "allowed_origin" {
  description = "CORS allowed origin for APIs"
  type        = string
  default     = "*"
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}

variable "hls_signing_secret" {
  type      = string
  sensitive = true
}

variable "firebase_service_account_json" {
  type      = string
  sensitive = true
}

variable "stream_key" {
  type      = string
  sensitive = true
}

variable "activities_secret_key_base" {
  description = "Phoenix SECRET_KEY_BASE (mix phx.gen.secret)"
  type        = string
  sensitive   = true
}

# ── Mail ──────────────────────────────────────────────────────────────────────
variable "mail_host" {
  type    = string
  default = "smtp.gmail.com"
}

variable "mail_port" {
  type    = number
  default = 587
}

variable "mail_username" {
  type    = string
  default = ""
}

# ── ECS capacity ──────────────────────────────────────────────────────────────
variable "business_logic_desired_count" {
  type    = number
  default = 1
}

variable "stream_engine_desired_count" {
  type    = number
  default = 1
}

variable "record_service_desired_count" {
  type    = number
  default = 1
}

variable "activities_desired_count" {
  type    = number
  default = 1
}

variable "recommendations_desired_count" {
  type    = number
  default = 1
}

variable "frontend_desired_count" {
  type    = number
  default = 1
}
