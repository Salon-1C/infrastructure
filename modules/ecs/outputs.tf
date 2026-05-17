output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cluster_id" {
  value = aws_ecs_cluster.this.id
}

output "service_discovery_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.this.id
}

output "alb_arn" {
  value = aws_lb.alb.arn
}

output "alb_listener_arn" {
  description = "ARN of the ALB HTTP listener (API Gateway VPC Link)"
  value       = aws_lb_listener.http.arn
}

output "alb_dns_name" {
  description = "Public ALB DNS — main HTTP entry point for the platform"
  value       = aws_lb.alb.dns_name
}

output "nlb_dns_name" {
  description = "Public NLB DNS for RTMP (1935) and WebRTC (8889)"
  value       = aws_lb.nlb.dns_name
}

output "business_logic_service_name" {
  value = aws_ecs_service.business_logic.name
}

output "stream_engine_service_name" {
  value = aws_ecs_service.stream_engine.name
}

output "record_service_name" {
  value = aws_ecs_service.record_service.name
}

output "activities_service_name" {
  value = aws_ecs_service.activities.name
}

output "recommendations_service_name" {
  value = aws_ecs_service.recommendations.name
}

output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}
