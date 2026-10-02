variable "name" {
  description = "Replication group id / name prefix (max 40 chars)."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "subnet_ids" {
  description = "Isolated subnets (no internet route) for the cache nodes, one per AZ."
  type        = list(string)
}

variable "engine_version" {
  description = "Redis OSS engine version."
  type        = string
  default     = "7.1"
}

variable "parameter_group_name" {
  description = "Parameter group (must match the engine major version)."
  type        = string
  default     = "default.redis7"
}

variable "node_type" {
  description = "Cache node type."
  type        = string
  default     = "cache.t4g.micro"
}

variable "port" {
  description = "Redis port."
  type        = number
  default     = 6379
}

variable "replicas" {
  description = "Number of read replicas. > 0 enables automatic failover + Multi-AZ."
  type        = number
  default     = 0

  validation {
    condition     = var.replicas >= 0 && var.replicas <= 5
    error_message = "replicas must be between 0 and 5."
  }
}

variable "snapshot_retention_days" {
  description = "Days to keep automatic snapshots (0 disables)."
  type        = number
  default     = 0
}

variable "snapshot_window" {
  description = "Daily snapshot window (UTC)."
  type        = string
  default     = "02:00-03:00"
}

variable "maintenance_window" {
  description = "Weekly maintenance window (UTC)."
  type        = string
  default     = "sun:03:30-sun:04:30"
}

variable "apply_immediately" {
  description = "Apply modifications immediately instead of in the maintenance window."
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "Customer-managed KMS key for at-rest + secret encryption (null = AWS-managed)."
  type        = string
  default     = null
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window (0 = delete immediately, handy for dev)."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
