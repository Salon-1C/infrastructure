variable "project" {
  type = string
}

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

variable "ecs_task_execution_role_arn" {
  type = string
}

variable "business_logic_task_role_arn" {
  type = string
}

variable "stream_engine_task_role_arn" {
  type = string
}

variable "record_service_task_role_arn" {
  type = string
}

variable "activities_task_role_arn" {
  type = string
}

variable "recommendations_task_role_arn" {
  type = string
}

variable "frontend_task_role_arn" {
  type = string
}

variable "blume_backend_image_url" {
  type = string
}

variable "stream_engine_image_url" {
  type = string
}

variable "record_service_image_url" {
  type = string
}

variable "blume_wa_image_url" {
  type = string
}

variable "activities_ms_image_url" {
  type = string
}

variable "recommendations_ms_image_url" {
  type = string
}

variable "mediamtx_image_url" {
  type = string
}

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

variable "activities_db_host" {
  type = string
}

variable "activities_db_name" {
  type    = string
  default = "stream_activities"
}

variable "activities_db_user" {
  type    = string
  default = "blume"
}

variable "activities_db_password_secret_arn" {
  type = string
}

variable "recordings_db_host" {
  type = string
}

variable "recordings_db_name" {
  type    = string
  default = "recordings"
}

variable "recordings_db_password_secret_arn" {
  type = string
}

variable "recordings_bucket_name" {
  type = string
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
  type      = string
  sensitive = true
}

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
  type    = string
  default = "*"
}

variable "public_app_url" {
  description = "Public base URL for the web app (Next.js NEXT_PUBLIC_* build args)"
  type        = string
}

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

variable "business_logic_cpu" {
  type    = number
  default = 512
}

variable "business_logic_memory" {
  type    = number
  default = 1024
}

variable "stream_engine_cpu" {
  type    = number
  default = 1024
}

variable "stream_engine_memory" {
  type    = number
  default = 2048
}

variable "record_service_cpu" {
  type    = number
  default = 512
}

variable "record_service_memory" {
  type    = number
  default = 1024
}

variable "activities_cpu" {
  type    = number
  default = 512
}

variable "activities_memory" {
  type    = number
  default = 1024
}

variable "recommendations_cpu" {
  type    = number
  default = 256
}

variable "recommendations_memory" {
  type    = number
  default = 512
}

variable "frontend_cpu" {
  type    = number
  default = 512
}

variable "frontend_memory" {
  type    = number
  default = 1024
}
