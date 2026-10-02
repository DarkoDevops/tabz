variable "name" {
  description = "ALB name (max 32 chars)."
  type        = string
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets (one per AZ) for the ALB."
  type        = list(string)
}

variable "allowed_cidrs" {
  description = "CIDRs allowed to reach the listeners."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certificate_arn" {
  description = "ACM certificate ARN. When set, an HTTPS listener is created and HTTP redirects to it."
  type        = string
  default     = null
}

variable "deletion_protection" {
  description = "Protect the ALB from deletion."
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket for ALB access logs (null disables them)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
