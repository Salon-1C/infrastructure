output "blume_backend_url" {
  description = "ECR repository URL for blume-backend"
  value       = aws_ecr_repository.blume_backend.repository_url
}

output "stream_engine_url" {
  description = "ECR repository URL for stream-engine"
  value       = aws_ecr_repository.stream_engine.repository_url
}

output "record_service_url" {
  description = "ECR repository URL for record-service"
  value       = aws_ecr_repository.record_service.repository_url
}

output "registry_id" {
  description = "AWS account ID / ECR registry ID"
  value       = aws_ecr_repository.blume_backend.registry_id
}
