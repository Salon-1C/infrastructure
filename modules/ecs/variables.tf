variable "project" {
  description = "Project name prefix"
  type        = string
}

# ── Networking ────────────────────────────────────────────────────────────────
variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "ecs_sg_id" {
  type = string
}

# ── IAM ───────────────────────────────────────────────────────────────────────
variable "ecs_task_execution_role_arn" {
  type = string
}

variable "business_logic_task_role_arn" {
  type = string
}

variable "stream_engine_task_role_arn" {
  type = string
}

# ── ECR images ────────────────────────────────────────────────────────────────
variable "blume_backend_image_url" {
  description = "ECR repository URL for blume-backend (without tag)"
  type        = string
}

variable "stream_engine_image_url" {
  description = "ECR repository URL for stream-engine (without tag)"
  type        = string
}

# ── RDS ───────────────────────────────────────────────────────────────────────
variable "db_host" {
  type = string
}

variable "db_name" {
  type    = string
  default = "blume"
}

variable "db_password_secret_arn" {
  type = string
}

# ── App secrets ───────────────────────────────────────────────────────────────
variable "jwt_secret" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true
}

variable "hls_signing_secret" {
  description = "HLS URL signing secret"
  type        = string
  sensitive   = true
}

variable "firebase_service_account_json" {
  description = "Firebase service account JSON (full contents)"
  type        = string
  sensitive   = true
}

variable "stream_key" {
  description = "RTMP stream key"
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

variable "allowed_origin" {
  description = "CORS allowed origin for the API"
  type        = string
  default     = "*"
}

# ── Capacity ──────────────────────────────────────────────────────────────────
variable "business_logic_cpu" {
  type    = number
  default = 512
}

variable "business_logic_memory" {
  type    = number
  default = 1024
}

variable "business_logic_desired_count" {
  type    = number
  default = 1
}

variable "stream_engine_cpu" {
  type    = number
  default = 512
}

variable "stream_engine_memory" {
  type    = number
  default = 1024
}

variable "stream_engine_desired_count" {
  type    = number
  default = 1
}
