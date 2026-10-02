include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/ecs-cluster.hcl"
  expose = true
}

inputs = {
  container_insights        = "disabled"
  default_capacity_provider = "FARGATE_SPOT"
}
