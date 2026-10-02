locals {
  # Account id is derived from the cluster ARN so the module needs no data sources
  # (keeps `plan` fully offline-capable, see README "mock mode").
  account_id = split(":", var.cluster_arn)[4]

  secret_value_from = {
    for name, s in var.secrets : name => s.key == null ? s.arn : "${s.arn}:${s.key}::"
  }
  secret_arns = distinct([for s in values(var.secrets) : s.arn])

  # ECS Exec does not support a read-only root fs (the SSM agent writes into the container).
  readonly_root_filesystem = var.readonly_root_filesystem && !var.enable_execute_command

  volumes = {
    for p in var.writable_paths : replace(trim(p, "/"), "/", "-") => p
  }

  log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.this.name
      awslogs-region        = var.region
      awslogs-stream-prefix = var.name
    }
  }

  main_container = {
    name      = var.container_name
    image     = var.container_image
    essential = true

    portMappings = [{
      name          = var.container_name
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = [for k in sort(keys(var.environment)) : { name = k, value = var.environment[k] }]
    secrets     = [for k in sort(keys(local.secret_value_from)) : { name = k, valueFrom = local.secret_value_from[k] }]

    readonlyRootFilesystem = local.readonly_root_filesystem
    mountPoints            = [for v, p in local.volumes : { sourceVolume = v, containerPath = p, readOnly = false }]

    # initProcessEnabled reaps zombies and is required for ECS Exec.
    linuxParameters  = { initProcessEnabled = true }
    logConfiguration = local.log_configuration
  }

  sidecar_containers = [
    for name, s in var.sidecars : merge(
      {
        name                   = name
        image                  = s.image
        essential              = s.essential
        cpu                    = s.cpu
        environment            = [for k in sort(keys(s.environment)) : { name = k, value = s.environment[k] }]
        secrets                = [for k in sort(s.secrets) : { name = k, valueFrom = local.secret_value_from[k] }]
        readonlyRootFilesystem = local.readonly_root_filesystem
        linuxParameters        = { initProcessEnabled = true }
        logConfiguration       = local.log_configuration
        # Sidecars start only after the main container is up.
        dependsOn = [{ containerName = var.container_name, condition = "START" }]
      },
      s.command == null ? {} : { command = s.command },
      s.entrypoint == null ? {} : { entryPoint = s.entrypoint },
      s.memory == null ? {} : { memory = s.memory },
    )
  ]
}

################################################################################
# Logs
################################################################################

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

################################################################################
# Task definition
################################################################################

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "volume" {
    for_each = local.volumes
    content {
      name = volume.key
    }
  }

  container_definitions = jsonencode(concat([local.main_container], local.sidecar_containers))

  tags = var.tags
}

################################################################################
# Service
################################################################################

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  enable_execute_command            = var.enable_execute_command
  health_check_grace_period_seconds = var.load_balancer == null ? null : var.health_check_grace_period_seconds
  propagate_tags                    = "SERVICE"
  enable_ecs_managed_tags           = true
  # Re-spread tasks across AZs after an AZ recovers.
  availability_zone_rebalancing = "ENABLED"

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer == null ? [] : [var.load_balancer]
    content {
      target_group_arn = aws_lb_target_group.this[0].arn
      container_name   = var.container_name
      container_port   = var.container_port
    }
  }

  lifecycle {
    # desired_count is owned by Application Auto Scaling after the first apply.
    ignore_changes = [desired_count]

    precondition {
      condition     = try(var.autoscaling.requests_per_target, null) == null || var.load_balancer != null
      error_message = "autoscaling.requests_per_target requires load_balancer to be set."
    }
  }

  # The target group must be attached to a listener before ECS can register targets.
  depends_on = [aws_lb_listener_rule.this, aws_iam_role_policy.execution]

  tags = var.tags
}
