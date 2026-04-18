output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "alb_arn" {
  value = aws_lb.alb.arn
}

output "alb_listener_arn" {
  description = "ARN of the ALB HTTP listener (used by API Gateway integration)"
  value       = aws_lb_listener.http.arn
}

output "alb_dns_name" {
  description = "Internal ALB DNS (used by API Gateway VPC Link)"
  value       = aws_lb.alb.dns_name
}

output "nlb_dns_name" {
  description = "Public NLB DNS for RTMP/WebRTC"
  value       = aws_lb.nlb.dns_name
}

output "business_logic_service_name" {
  value = aws_ecs_service.business_logic.name
}

output "stream_engine_service_name" {
  value = aws_ecs_service.stream_engine.name
}
