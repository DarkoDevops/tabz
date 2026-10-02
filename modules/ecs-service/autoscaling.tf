locals {
  autoscaling_enabled = var.autoscaling != null

  target_tracking = !local.autoscaling_enabled ? {} : {
    for k, v in {
      requests = {
        metric = "ALBRequestCountPerTarget"
        target = var.autoscaling.requests_per_target
      }
      cpu = {
        metric = "ECSServiceAverageCPUUtilization"
        target = var.autoscaling.cpu_target
      }
      memory = {
        metric = "ECSServiceAverageMemoryUtilization"
        target = var.autoscaling.memory_target
      }
    } : k => v if v.target != null
  }
}

resource "aws_appautoscaling_target" "this" {
  count = local.autoscaling_enabled ? 1 : 0

  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  min_capacity       = var.autoscaling.min_capacity
  max_capacity       = var.autoscaling.max_capacity
  tags               = var.tags
}

resource "aws_appautoscaling_policy" "this" {
  for_each = local.target_tracking

  name               = "${var.name}-${each.key}"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  resource_id        = aws_appautoscaling_target.this[0].resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target
    scale_in_cooldown  = var.autoscaling.scale_in_cooldown
    scale_out_cooldown = var.autoscaling.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = each.value.metric
      resource_label = each.key == "requests" ? join("/", [
        var.load_balancer.arn_suffix,
        aws_lb_target_group.this[0].arn_suffix,
      ]) : null
    }
  }
}

resource "aws_appautoscaling_scheduled_action" "this" {
  for_each = local.autoscaling_enabled ? var.autoscaling.scheduled_actions : {}

  name               = "${var.name}-${each.key}"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  schedule           = each.value.schedule
  timezone           = each.value.timezone

  scalable_target_action {
    min_capacity = each.value.min_capacity
    max_capacity = each.value.max_capacity
  }
}
