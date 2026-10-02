# Offline unit tests: `terraform test` from modules/ecs-service. No AWS credentials needed.

mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:eu-central-1:111111111111:targetgroup/svc-tg/0123456789abcdef"
      arn_suffix = "targetgroup/svc-tg/0123456789abcdef"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111111111111:role/mock"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:eu-central-1:111111111111:task-definition/svc:1"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:eu-central-1:111111111111:log-group:/ecs/svc"
    }
  }
}

variables {
  name            = "svc"
  region          = "eu-central-1"
  cluster_arn     = "arn:aws:ecs:eu-central-1:111111111111:cluster/test"
  cluster_name    = "test"
  vpc_id          = "vpc-0123456789abcdef0"
  subnet_ids      = ["subnet-01", "subnet-02"]
  container_image = "nginxinc/nginx-unprivileged:1.27-alpine"

  secrets = {
    REDIS_AUTH_TOKEN = {
      arn = "arn:aws:secretsmanager:eu-central-1:111111111111:secret:redis-AbCdEf"
      key = "auth_token"
    }
  }

  egress_to_security_groups = {
    redis = { security_group_id = "sg-0redis", port = 6379 }
  }

  load_balancer = {
    listener_arn      = "arn:aws:elasticloadbalancing:eu-central-1:111111111111:listener/app/alb/0123/4567"
    security_group_id = "sg-0alb"
    arn_suffix        = "app/alb/0123"
    priority          = 100
  }
}

run "secret_is_injected_by_json_key" {
  command = apply

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets[0].valueFrom == "arn:aws:secretsmanager:eu-central-1:111111111111:secret:redis-AbCdEf:auth_token::"
    error_message = "Secret must be referenced by ARN + JSON key, never as a plain env var."
  }

  assert {
    condition     = length(jsondecode(aws_ecs_task_definition.this.container_definitions)[0].environment) == 0
    error_message = "No plain-text environment expected."
  }
}

run "redis_rule_pair_is_sg_to_sg" {
  command = apply

  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.dependency_from_service["redis"].security_group_id == "sg-0redis" &&
      aws_vpc_security_group_ingress_rule.dependency_from_service["redis"].from_port == 6379 &&
      aws_vpc_security_group_ingress_rule.dependency_from_service["redis"].cidr_ipv4 == null
    )
    error_message = "Redis must get an SG-referenced ingress rule on 6379 only."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.to_dependency["redis"].to_port == 6379
    error_message = "Service SG must allow egress to Redis on 6379."
  }
}

run "tasks_are_private" {
  command = plan

  assert {
    condition     = one(aws_ecs_service.this.network_configuration).assign_public_ip == false
    error_message = "Tasks must not get public IPs."
  }
}

run "autoscaling_policies_follow_inputs" {
  command = apply

  variables {
    autoscaling = {
      min_capacity        = 3
      max_capacity        = 12
      requests_per_target = 500
      cpu_target          = 60
    }
  }

  assert {
    condition     = toset(keys(aws_appautoscaling_policy.this)) == toset(["requests", "cpu"])
    error_message = "Expected exactly the requests + cpu target-tracking policies."
  }

  assert {
    condition     = aws_appautoscaling_target.this[0].resource_id == "service/test/svc"
    error_message = "Scalable target must point at the ECS service."
  }
}

run "request_scaling_requires_alb" {
  command = plan

  variables {
    load_balancer = null
    autoscaling = {
      min_capacity        = 1
      max_capacity        = 2
      requests_per_target = 100
    }
  }

  expect_failures = [aws_ecs_service.this]
}

run "sidecar_cannot_reference_unknown_secret" {
  command = plan

  variables {
    sidecars = {
      probe = { image = "redis:7", secrets = ["NOT_DECLARED"] }
    }
  }

  expect_failures = [var.sidecars]
}

run "ecs_exec_disables_readonly_root_fs" {
  command = apply

  variables {
    enable_execute_command = true
  }

  assert {
    condition     = alltrue([for c in jsondecode(aws_ecs_task_definition.this.container_definitions) : c.readonlyRootFilesystem == false])
    error_message = "ECS Exec requires a writable root filesystem."
  }
}

run "readonly_root_fs_by_default" {
  command = apply

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].readonlyRootFilesystem == true
    error_message = "Containers must be read-only by default."
  }
}
