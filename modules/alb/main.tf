locals {
  https_enabled = var.certificate_arn != null
}

resource "aws_security_group" "this" {
  name_prefix = "${var.name}-alb-"
  description = "Public ALB ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

# Ingress is open to the internet on the listener ports only. Egress rules are NOT defined
# here: every ecs-service attached to this ALB adds its own egress rule to its own SG.
resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.allowed_cidrs)

  security_group_id = aws_security_group.this.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
  tags              = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = local.https_enabled ? toset(var.allowed_cidrs) : toset([])

  security_group_id = aws_security_group.this.id
  description       = "HTTPS"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
  tags              = var.tags
}

resource "aws_lb" "this" {
  name               = var.name
  load_balancer_type = "application"
  internal           = false
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.this.id]

  enable_deletion_protection = var.deletion_protection
  drop_invalid_header_fields = true
  idle_timeout               = 60

  dynamic "access_logs" {
    for_each = var.access_logs_bucket == null ? [] : [1]
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.name
      enabled = true
    }
  }

  tags = var.tags
}

# Without a certificate: plain HTTP listener that services attach to.
# With a certificate: HTTP only redirects to HTTPS, services attach to the HTTPS listener.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = local.https_enabled ? "redirect" : "fixed-response"

    dynamic "redirect" {
      for_each = local.https_enabled ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "fixed_response" {
      for_each = local.https_enabled ? [] : [1]
      content {
        content_type = "text/plain"
        message_body = "Not found"
        status_code  = "404"
      }
    }
  }

  tags = var.tags
}

resource "aws_lb_listener" "https" {
  count = local.https_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not found"
      status_code  = "404"
    }
  }

  tags = var.tags
}
