variable "name" {
  description = "Cluster name."
  type        = string
}

variable "container_insights" {
  description = "Container Insights mode: disabled, enabled or enhanced."
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["disabled", "enabled", "enhanced"], var.container_insights)
    error_message = "container_insights must be disabled, enabled or enhanced."
  }
}

variable "default_capacity_provider" {
  description = "Default capacity provider for services that do not set a strategy."
  type        = string
  default     = "FARGATE"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
