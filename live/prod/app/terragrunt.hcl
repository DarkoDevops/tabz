include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/app.hcl"
  expose = true
}

# PROD: >= 3 tasks (one per AZ) always on on-demand Fargate; burst capacity is 50/50 on-demand/Spot.
inputs = {
  cpu    = 512
  memory = 1024

  desired_count = 3
  capacity_provider_strategy = [
    { capacity_provider = "FARGATE", weight = 1, base = 3 },
    { capacity_provider = "FARGATE_SPOT", weight = 1 },
  ]

  # Never drop below full capacity during a rolling deploy.
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  enable_execute_command = false
  log_retention_days     = 90

  autoscaling = {
    min_capacity        = 3
    max_capacity        = 12
    requests_per_target = 500
    cpu_target          = 60
    scale_out_cooldown  = 60
    scale_in_cooldown   = 300
  }
}
