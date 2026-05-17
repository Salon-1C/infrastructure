output "api_gateway_endpoint" {
  description = "HTTPS API Gateway endpoint (proxies to the ALB)"
  value       = module.api_gateway.api_endpoint
}

output "alb_dns_name" {
  description = "Public ALB DNS — HTTP entry point (same routes as local Traefik)"
  value       = "http://${module.ecs.alb_dns_name}"
}

output "nlb_dns_name" {
  description = "Public NLB DNS — RTMP ingest and WebRTC playback"
  value       = module.ecs.nlb_dns_name
}

output "rtmp_ingest_url" {
  description = "OBS server URL (stream key = var.stream_key)"
  value       = "rtmp://${module.ecs.nlb_dns_name}:1935/live"
}

output "ecs_cluster_name" {
  description = "ECS cluster name for GitHub Actions redeploys"
  value       = module.ecs.cluster_name
}

output "ecr_repository_urls" {
  description = "ECR URLs for all component images"
  value       = module.ecr.repository_urls
}

output "github_deploy_role_arn" {
  description = "Set as AWS_ROLE_ARN secret in each component repository"
  value       = module.iam.github_deploy_role_arn
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "recordings_rds_endpoint" {
  value = module.rds_recordings.endpoint
}

output "activities_rds_endpoint" {
  value = module.rds_activities.endpoint
}

output "recordings_bucket_name" {
  value = module.s3_recordings.bucket_name
}

output "ecs_services" {
  description = "ECS service names (for workflow ECS_SERVICE values)"
  value = {
    business_logic  = module.ecs.business_logic_service_name
    stream_engine   = module.ecs.stream_engine_service_name
    record_service  = module.ecs.record_service_name
    activities      = module.ecs.activities_service_name
    recommendations = module.ecs.recommendations_service_name
    frontend        = module.ecs.frontend_service_name
  }
}
