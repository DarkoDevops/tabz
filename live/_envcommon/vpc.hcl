# Common VPC config. Subnet layout per AZ (i = AZ index):
#   private      10.x.(i*16).0/20   - ECS tasks, egress via NAT
#   public       10.x.(192+i).0/24  - ALB + NAT gateways
#   elasticache  10.x.(208+i).0/24  - Redis, NO route to the internet
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=6.7.3"
}

locals {
  env  = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name = "tabz-${local.env.environment}"
}

inputs = {
  name = local.name
  cidr = local.env.vpc_cidr
  azs  = local.env.azs

  private_subnets     = [for i, _ in local.env.azs : cidrsubnet(local.env.vpc_cidr, 4, i)]
  public_subnets      = [for i, _ in local.env.azs : cidrsubnet(local.env.vpc_cidr, 8, 192 + i)]
  elasticache_subnets = [for i, _ in local.env.azs : cidrsubnet(local.env.vpc_cidr, 8, 208 + i)]

  # The redis module owns its subnet group.
  create_elasticache_subnet_group       = false
  create_elasticache_subnet_route_table = true

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Lock down the default SG so nothing accidentally relies on it.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}
