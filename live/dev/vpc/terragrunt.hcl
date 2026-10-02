include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/vpc.hcl"
  expose = true
}

# DEV: one NAT gateway shared by all AZs (cost over HA - an AZ outage only affects dev egress).
inputs = {
  single_nat_gateway = true
}
