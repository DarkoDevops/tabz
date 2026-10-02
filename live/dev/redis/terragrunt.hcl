include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/redis.hcl"
  expose = true
}

# DEV: single node, no failover, no snapshots, secret deletable immediately.
inputs = {
  node_type                   = "cache.t4g.micro"
  replicas                    = 0
  snapshot_retention_days     = 0
  secret_recovery_window_days = 0
  apply_immediately           = true
}
