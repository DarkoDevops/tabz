include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/redis.hcl"
  expose = true
}

# PROD: primary + 2 replicas spread over 3 AZs, automatic failover + Multi-AZ, daily snapshots.
inputs = {
  node_type                   = "cache.r7g.large"
  replicas                    = 2
  snapshot_retention_days     = 7
  secret_recovery_window_days = 30
  apply_immediately           = false
}
