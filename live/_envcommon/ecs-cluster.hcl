terraform {
  source = "${get_repo_root()}/modules//ecs-cluster"
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

inputs = {
  name = "tabz-${local.env.environment}"
}
