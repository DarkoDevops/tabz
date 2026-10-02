################################################################################
# Service security group
################################################################################

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-svc-"
  description = "ECS service ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-svc" })

  lifecycle {
    create_before_destroy = true
  }
}

# Outbound HTTPS: ECR, Secrets Manager, CloudWatch Logs (through NAT or VPC endpoints).
resource "aws_vpc_security_group_egress_rule" "https" {
  count = var.allow_https_egress ? 1 : 0

  security_group_id = aws_security_group.this.id
  description       = "HTTPS to AWS APIs / registries"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  tags              = var.tags
}

################################################################################
# ALB <-> service (rule pair: ALB egress + service ingress, SG-to-SG only)
################################################################################

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  count = var.load_balancer == null ? 0 : 1

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.load_balancer.security_group_id
  description                  = "From ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  tags                         = var.tags
}

resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
  count = var.load_balancer == null ? 0 : 1

  security_group_id            = var.load_balancer.security_group_id
  referenced_security_group_id = aws_security_group.this.id
  description                  = "To ECS service ${var.name}"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  tags                         = var.tags
}

################################################################################
# Service -> dependencies (Redis etc.), rule pair owned by the consumer
################################################################################

resource "aws_vpc_security_group_egress_rule" "to_dependency" {
  for_each = var.egress_to_security_groups

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value.security_group_id
  description                  = coalesce(each.value.description, "To ${each.key}")
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  tags                         = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "dependency_from_service" {
  for_each = var.egress_to_security_groups

  security_group_id            = each.value.security_group_id
  referenced_security_group_id = aws_security_group.this.id
  description                  = "From ECS service ${var.name}"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  tags                         = var.tags
}

################################################################################
# Target group + listener rule
################################################################################

resource "aws_lb_target_group" "this" {
  count = var.load_balancer == null ? 0 : 1

  name                 = "${var.name}-tg"
  vpc_id               = var.vpc_id
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = var.load_balancer.deregistration_delay

  health_check {
    path                = var.load_balancer.health_check.path
    matcher             = var.load_balancer.health_check.matcher
    interval            = var.load_balancer.health_check.interval
    healthy_threshold   = var.load_balancer.health_check.healthy_threshold
    unhealthy_threshold = var.load_balancer.health_check.unhealthy_threshold
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "this" {
  count = var.load_balancer == null ? 0 : 1

  listener_arn = var.load_balancer.listener_arn
  priority     = var.load_balancer.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    path_pattern {
      values = var.load_balancer.path_patterns
    }
  }

  dynamic "condition" {
    for_each = length(var.load_balancer.host_headers) > 0 ? [1] : []
    content {
      host_header {
        values = var.load_balancer.host_headers
      }
    }
  }

  tags = var.tags
}
