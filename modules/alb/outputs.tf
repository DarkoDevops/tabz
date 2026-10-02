output "alb_arn" {
  description = "ALB ARN."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix (used for ALBRequestCountPerTarget autoscaling)."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "security_group_id" {
  description = "ALB security group."
  value       = aws_security_group.this.id
}

output "listener_arn" {
  description = "Listener services should attach their rules to (HTTPS when a certificate is set, else HTTP)."
  value       = local.https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}
