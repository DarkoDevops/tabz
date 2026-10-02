################################################################################
# Identity / placement
################################################################################

variable "name" {
  description = "Service name. Used as prefix for every resource created by this module."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,28}$", var.name))
    error_message = "name must be 1-28 chars of lowercase letters, digits and dashes (target group names are capped at 32 chars)."
  }
}

variable "region" {
  description = "AWS region (used for the awslogs driver)."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster to run the service in."
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster (needed to build the autoscaling resource id)."
  type        = string
}

variable "vpc_id" {
  description = "VPC the tasks run in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the tasks (awsvpc mode, no public IP)."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

################################################################################
# Task / container
################################################################################

variable "cpu" {
  description = "Task CPU units (Fargate valid combinations only)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 512
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64. Note: Fargate Spot only supports X86_64."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "container_name" {
  description = "Name of the main (load-balanced) container."
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Image of the main container. Pin by tag or digest."
  type        = string
}

variable "container_port" {
  description = "Port the main container listens on."
  type        = number
  default     = 8080
}

variable "environment" {
  description = "Plain-text environment variables for the main container."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = <<-EOT
    Secrets injected as environment variables at task start (never stored in the task definition).
    Map key = env var name. `key` selects a JSON key inside the secret; omit to inject the whole secret.
    The execution role is automatically granted GetSecretValue on exactly these ARNs.
  EOT
  type = map(object({
    arn = string
    key = optional(string)
  }))
  default = {}
}

variable "secrets_kms_key_arns" {
  description = "Customer-managed KMS keys encrypting the secrets (leave empty when secrets use the AWS-managed key)."
  type        = list(string)
  default     = []
}

variable "readonly_root_filesystem" {
  description = "Run containers with a read-only root filesystem. Forced off when enable_execute_command is true (ECS Exec limitation)."
  type        = bool
  default     = true
}

variable "writable_paths" {
  description = "Paths in the main container backed by ephemeral task storage (needed when the root fs is read-only, e.g. /tmp)."
  type        = list(string)
  default     = ["/tmp"]
}

variable "sidecars" {
  description = <<-EOT
    Additional containers in the same task. `secrets` references keys of var.secrets so that
    a sidecar can only receive secrets the task is already allowed to read.
  EOT
  type = map(object({
    image       = string
    command     = optional(list(string))
    entrypoint  = optional(list(string))
    essential   = optional(bool, false)
    cpu         = optional(number, 0)
    memory      = optional(number)
    environment = optional(map(string), {})
    secrets     = optional(list(string), [])
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.sidecars) : alltrue([for k in s.secrets : contains(keys(var.secrets), k)])])
    error_message = "Every sidecar secret must reference a key defined in var.secrets."
  }
}

variable "task_role_policy_json" {
  description = "Optional extra IAM policy (JSON) attached to the task role - what the application itself may call."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the service log group."
  type        = number
  default     = 14
}

################################################################################
# Service / deployment
################################################################################

variable "desired_count" {
  description = "Initial task count. Ignored after creation when autoscaling is enabled."
  type        = number
  default     = 1
}

variable "capacity_provider_strategy" {
  description = "Capacity provider strategy (FARGATE / FARGATE_SPOT)."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = optional(number, 0)
  }))
  default = [{ capacity_provider = "FARGATE", weight = 1, base = 0 }]
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower bound of running tasks during a deployment."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Upper bound of running tasks during a deployment."
  type        = number
  default     = 200
}

variable "enable_execute_command" {
  description = "Enable ECS Exec (shell into running tasks via SSM). Handy in dev, usually off in prod."
  type        = bool
  default     = false
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore ALB health checks after a task starts."
  type        = number
  default     = 30
}

################################################################################
# Networking / load balancing
################################################################################

variable "load_balancer" {
  description = <<-EOT
    Attach the service to an existing ALB listener. The module owns its target group and
    listener rule, so many services can share one ALB. Set to null for a worker service.
  EOT
  type = object({
    listener_arn      = string
    security_group_id = string
    arn_suffix        = string
    priority          = number
    path_patterns     = optional(list(string), ["/*"])
    host_headers      = optional(list(string), [])
    health_check = optional(object({
      path                = optional(string, "/")
      matcher             = optional(string, "200-399")
      interval            = optional(number, 15)
      healthy_threshold   = optional(number, 2)
      unhealthy_threshold = optional(number, 3)
    }), {})
    deregistration_delay = optional(number, 30)
  })
  default = null
}

variable "egress_to_security_groups" {
  description = <<-EOT
    Downstream dependencies this service must reach (Redis, RDS, ...). For each entry the module creates
    BOTH the egress rule on the service SG and the matching ingress rule on the target SG, so the
    dependency only ever trusts this exact service - no CIDR-based rules.
  EOT
  type = map(object({
    security_group_id = string
    port              = number
    description       = optional(string)
  }))
  default = {}
}

variable "allow_https_egress" {
  description = "Allow outbound 443 to 0.0.0.0/0 (ECR image pulls, Secrets Manager, CloudWatch Logs via NAT or VPC endpoints)."
  type        = bool
  default     = true
}

################################################################################
# Autoscaling
################################################################################

variable "autoscaling" {
  description = <<-EOT
    Target-tracking autoscaling. Any combination of signals may be enabled; the service scales out
    when ANY policy asks for it and only scales in when ALL agree.
      - requests_per_target: ALBRequestCountPerTarget (best leading signal for request-driven web apps)
      - cpu_target / memory_target: ECSService average utilization (%)
    scheduled_actions lets e.g. dev scale to zero outside working hours.
  EOT
  type = object({
    min_capacity        = number
    max_capacity        = number
    cpu_target          = optional(number)
    memory_target       = optional(number)
    requests_per_target = optional(number)
    scale_in_cooldown   = optional(number, 300)
    scale_out_cooldown  = optional(number, 60)
    scheduled_actions = optional(map(object({
      schedule     = string
      timezone     = optional(string, "UTC")
      min_capacity = number
      max_capacity = number
    })), {})
  })
  default = null

  validation {
    condition     = var.autoscaling == null || try(var.autoscaling.min_capacity <= var.autoscaling.max_capacity, false)
    error_message = "autoscaling.min_capacity must be <= max_capacity."
  }
}
