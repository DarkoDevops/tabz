# ---------------------------------------------------------------------------------------------------------------------
# Root Terragrunt configuration - included by every unit.
#   * S3 remote state (bucket auto-created by Terragrunt, S3-native locking, no DynamoDB)
#   * AWS provider with default tags + account guard
#   * TG_MOCK_AWS=true switches to local state + fake credentials so `plan` works with no AWS account at all
# ---------------------------------------------------------------------------------------------------------------------

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals

  project     = "tabz"
  environment = local.env_vars.environment
  account_id  = local.env_vars.account_id
  region      = local.env_vars.region

  mock_aws = get_env("TG_MOCK_AWS", "false") == "true"

  default_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "terragrunt"
    Repository  = "github.com/DarkoDevops/tabz"
    Unit        = path_relative_to_include()
  }

  backends = {
    s3 = {
      bucket       = "${local.project}-tfstate-${local.account_id}-${local.region}"
      key          = "${path_relative_to_include()}/terraform.tfstate"
      region       = local.region
      encrypt      = true
      use_lockfile = true
    }
    local = {
      path = "${get_parent_terragrunt_dir()}/.mock-state/${path_relative_to_include()}/terraform.tfstate"
    }
  }
  backend = local.mock_aws ? "local" : "s3"
}

terraform_version_constraint  = ">= 1.10"
terragrunt_version_constraint = ">= 0.67"

remote_state {
  backend = local.backend
  config  = local.backends[local.backend]

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.region}"
    %{if local.mock_aws~}
      # Mock mode: no AWS API calls are made during plan.
      access_key                  = "mock"
      secret_key                  = "mock"
      skip_credentials_validation = true
      skip_requesting_account_id  = true
      skip_metadata_api_check     = true
      skip_region_validation      = true
    %{else~}
      # Guard rail: refuse to run against the wrong account.
      allowed_account_ids = ["${local.account_id}"]
    %{endif~}

      default_tags {
        tags = ${jsonencode(local.default_tags)}
      }
    }
  EOF
}

inputs = {
  region = local.region
  tags   = local.default_tags
}
