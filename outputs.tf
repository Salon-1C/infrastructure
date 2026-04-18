output "api_gateway_endpoint" {
  description = "Public HTTPS endpoint for the HTTP API (business-logic + stream-engine HTTP APIs)"
  value       = module.api_gateway.api_endpoint
}

output "nlb_dns_name" {
  description = "Public NLB DNS name — point your RTMP client (OBS) and WebRTC viewer here"
  value       = module.ecs.nlb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name (used in GitHub Actions force-redeploy commands)"
  value       = module.ecs.cluster_name
}

output "blume_backend_ecr_url" {
  description = "ECR URL for business-logic image"
  value       = module.ecr.blume_backend_url
}

output "stream_engine_ecr_url" {
  description = "ECR URL for stream-engine image"
  value       = module.ecr.stream_engine_url
}

output "github_deploy_role_arn" {
  description = "Copy this ARN into AWS_ROLE_ARN secret in both GitHub repos"
  value       = module.iam.github_deploy_role_arn
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.rds.endpoint
}
