output "github_deploy_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions"
  value       = aws_iam_role.github_deploy.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "business_logic_task_role_arn" {
  description = "ARN of the ECS task role for business-logic"
  value       = aws_iam_role.business_logic_task.arn
}

output "stream_engine_task_role_arn" {
  description = "ARN of the ECS task role for stream-engine"
  value       = aws_iam_role.stream_engine_task.arn
}
