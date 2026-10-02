include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/vpc.hcl"
  expose = true
}

# PROD: one NAT gateway per AZ (no cross-AZ egress dependency) + VPC flow logs.
inputs = {
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # The community VPC module resolves the account id via STS when flow logs are on, which the
  # offline mock mode cannot answer -> flow logs are only skipped in TG_MOCK_AWS=true plans.
  enable_flow_log                                 = get_env("TG_MOCK_AWS", "false") != "true"
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_cloudwatch_log_group_retention_in_days = 90
  flow_log_traffic_type                           = "REJECT"
}
