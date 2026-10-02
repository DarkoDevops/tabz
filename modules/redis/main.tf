locals {
  num_cache_clusters = 1 + var.replicas
  ha_enabled         = var.replicas > 0
}

resource "aws_elasticache_subnet_group" "this" {
  name        = var.name
  description = "Isolated subnets for ${var.name}"
  subnet_ids  = var.subnet_ids
  tags        = var.tags
}

# No ingress rules here on purpose: each consumer (ecs-service module) adds an
# SG-referenced ingress rule for itself. Redis never trusts a CIDR range.
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-redis-"
  description = "ElastiCache ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-redis" })

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# AUTH token -> Secrets Manager (the single secret the app reads)
################################################################################

resource "random_password" "auth" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "auth" {
  name                    = "${var.name}/redis"
  description             = "Connection details + AUTH token for ${var.name} Redis"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "auth" {
  secret_id = aws_secretsmanager_secret.auth.id
  secret_string = jsonencode({
    auth_token = random_password.auth.result
    host       = aws_elasticache_replication_group.this.primary_endpoint_address
    port       = var.port
  })
}

################################################################################
# Replication group
################################################################################

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "Redis for ${var.name}"

  engine               = "redis"
  engine_version       = var.engine_version
  parameter_group_name = var.parameter_group_name
  node_type            = var.node_type
  port                 = var.port

  num_cache_clusters         = local.num_cache_clusters
  automatic_failover_enabled = local.ha_enabled
  multi_az_enabled           = local.ha_enabled

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.this.id]

  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = random_password.auth.result

  snapshot_retention_limit   = var.snapshot_retention_days
  maintenance_window         = var.maintenance_window
  snapshot_window            = var.snapshot_retention_days > 0 ? var.snapshot_window : null
  auto_minor_version_upgrade = true
  apply_immediately          = var.apply_immediately

  tags = var.tags
}
