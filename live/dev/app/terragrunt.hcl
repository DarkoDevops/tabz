include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/app.hcl"
  expose = true
}

# DEV: smallest task, 100% Fargate Spot, ECS Exec on, scale to zero outside office hours.
inputs = {
  cpu    = 256
  memory = 512

  desired_count = 1
  capacity_provider_strategy = [
    { capacity_provider = "FARGATE_SPOT", weight = 1 },
  ]

  # Allow the single task to be replaced in place (0% healthy during deploys is fine in dev).
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  enable_execute_command = true
  log_retention_days     = 7

  autoscaling = {
    min_capacity        = 1
    max_capacity        = 3
    requests_per_target = 1000
    cpu_target          = 75

    scheduled_actions = {
      night = {
        schedule     = "cron(0 20 ? * MON-FRI *)"
        timezone     = "Europe/Zurich"
        min_capacity = 0
        max_capacity = 0
      }
      morning = {
        schedule     = "cron(0 7 ? * MON-FRI *)"
        timezone     = "Europe/Zurich"
        min_capacity = 1
        max_capacity = 3
      }
    }
  }
}
