output "blume_backend_url" {
  description = "ECR repository URL for blume-backend"
  value       = aws_ecr_repository.this["blume-backend"].repository_url
}

output "stream_engine_url" {
  description = "ECR repository URL for stream-engine"
  value       = aws_ecr_repository.this["stream-engine"].repository_url
}

output "record_service_url" {
  description = "ECR repository URL for record-service"
  value       = aws_ecr_repository.this["record-service"].repository_url
}

output "blume_wa_url" {
  description = "ECR repository URL for blume-wa"
  value       = aws_ecr_repository.this["blume-wa"].repository_url
}

output "activities_ms_url" {
  description = "ECR repository URL for activities-ms"
  value       = aws_ecr_repository.this["activities-ms"].repository_url
}

output "recommendations_ms_url" {
  description = "ECR repository URL for recommendations-ms"
  value       = aws_ecr_repository.this["recommendations-ms"].repository_url
}

output "mediamtx_url" {
  description = "ECR repository URL for blume-mediamtx (MediaMTX + ffmpeg config)"
  value       = aws_ecr_repository.this["blume-mediamtx"].repository_url
}

output "repository_urls" {
  description = "Map of ECR repository name to URL"
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "registry_id" {
  description = "AWS account ID / ECR registry ID"
  value       = aws_ecr_repository.this["blume-backend"].registry_id
}
