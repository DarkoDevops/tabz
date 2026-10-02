output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "service_id" {
  description = "ECS service ARN."
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "Task definition revision currently referenced by the service."
  value       = aws_ecs_task_definition.this.arn
}

output "security_group_id" {
  description = "Security group attached to the tasks."
  value       = aws_security_group.this.id
}

output "task_role_arn" {
  description = "IAM role assumed by the application."
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "IAM role used by the ECS agent."
  value       = aws_iam_role.execution.arn
}

output "log_group_name" {
  description = "CloudWatch log group of all containers in the task."
  value       = aws_cloudwatch_log_group.this.name
}

output "target_group_arn" {
  description = "Target group ARN (null when not load balanced)."
  value       = try(aws_lb_target_group.this[0].arn, null)
}
