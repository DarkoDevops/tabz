output "primary_endpoint" {
  description = "Primary (read/write) endpoint DNS name."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "reader_endpoint" {
  description = "Reader endpoint DNS name (load-balances across replicas)."
  value       = aws_elasticache_replication_group.this.reader_endpoint_address
}

output "port" {
  description = "Redis port."
  value       = var.port
}

output "security_group_id" {
  description = "Security group of the cache nodes - consumers add their own ingress rule to it."
  value       = aws_security_group.this.id
}

output "auth_secret_arn" {
  description = "Secrets Manager secret holding {auth_token, host, port}."
  value       = aws_secretsmanager_secret.auth.arn
}
