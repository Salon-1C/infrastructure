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
  description = "GitHub organization name (must match the org that owns business-logic and stream-engine repos)"
  type        = string
}

# ── Database ──────────────────────────────────────────────────────────────────
variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "blume"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "recordings_db_name" {
  description = "MySQL database name for recordings microservice"
  type        = string
  default     = "recordings"
}

variable "recordings_db_instance_class" {
  description = "RDS instance class for recordings database"
  type        = string
  default     = "db.t3.micro"
}

variable "recordings_bucket_name" {
  description = "S3 bucket name for recorded files"
  type        = string
}

# ── Application ───────────────────────────────────────────────────────────────
variable "allowed_origin" {
  description = "CORS allowed origin for the Spring Boot API (e.g. https://app.example.com)"
  type        = string
  default     = "*"
}

variable "jwt_secret" {
  description = "JWT signing secret for business-logic"
  type        = string
  sensitive   = true
}

variable "hls_signing_secret" {
  description = "HLS URL signing secret for business-logic"
  type        = string
  sensitive   = true
}

variable "firebase_service_account_json" {
  description = "Full contents of the Firebase service account JSON"
  type        = string
  sensitive   = true
}

variable "stream_key" {
  description = "RTMP stream key used by OBS / MediaMTX auth"
  type        = string
  sensitive   = true
}

# ── Mail ──────────────────────────────────────────────────────────────────────
variable "mail_host" {
  description = "SMTP host"
  type        = string
  default     = "smtp.gmail.com"
}

variable "mail_port" {
  description = "SMTP port"
  type        = number
  default     = 587
}

variable "mail_username" {
  description = "SMTP username"
  type        = string
  default     = ""
}

# ── ECS Capacity (override for scaling) ──────────────────────────────────────
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
