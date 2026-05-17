output "github_deploy_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions"
  value       = aws_iam_role.github_deploy.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "business_logic_task_role_arn" {
  value = aws_iam_role.business_logic_task.arn
}

output "stream_engine_task_role_arn" {
  value = aws_iam_role.stream_engine_task.arn
}

output "record_service_task_role_arn" {
  value = aws_iam_role.record_service_task.arn
}

output "activities_task_role_arn" {
  value = aws_iam_role.activities_task.arn
}

output "recommendations_task_role_arn" {
  value = aws_iam_role.recommendations_task.arn
}

output "frontend_task_role_arn" {
  value = aws_iam_role.frontend_task.arn
}
