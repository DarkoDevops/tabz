terraform {
  source = "${get_repo_root()}/modules//redis"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../vpc"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    vpc_id              = "vpc-0123456789abcdef0"
    elasticache_subnets = ["subnet-0ccccccccccccccc1", "subnet-0ccccccccccccccc2", "subnet-0ccccccccccccccc3"]
  }
}

inputs = {
  name       = "tabz-${local.env.environment}"
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.elasticache_subnets
}
