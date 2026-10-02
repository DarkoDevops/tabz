# ---------------------------------------------------------------------------------------------------------------------
# "web" application = nginx (stand-in for any HTTP app) + a redis-probe sidecar that proves the
# task can reach ElastiCache over the network, through the security groups, over TLS, with the
# AUTH token read from Secrets Manager. Environments override sizing/scaling only.
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  source = "${get_repo_root()}/modules//ecs-service"
}

locals {
  env  = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
  name = "tabz-${local.env.environment}-web"

  # NOTE: no shell "$${...}" syntax in here - Terragrunt hands complex inputs to Terraform as HCL,
  # so it would be re-parsed as an interpolation.
  # Probe loop: PING Redis every 30s and log the outcome. Failure modes are distinguishable in logs:
  #   "Connection timed out"  -> routing / security group problem
  #   "SSL" / "TLS" error     -> transit encryption mismatch
  #   "WRONGPASS"/"NOAUTH"    -> wrong / missing secret
  #   "PONG"                  -> network + SG + TLS + AUTH all OK
  redis_probe_script = <<-EOT
    while true; do
      out=$(timeout 5 redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" --tls \
            --cacert /etc/ssl/certs/ca-certificates.crt \
            -a "$REDIS_AUTH_TOKEN" --no-auth-warning PING 2>&1)
      [ -n "$out" ] || out="timeout"
      echo "redis-probe host=$REDIS_HOST port=$REDIS_PORT result=$out"
      sleep 30
    done
  EOT
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../vpc"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    vpc_id          = "vpc-0123456789abcdef0"
    private_subnets = ["subnet-0bbbbbbbbbbbbbbb1", "subnet-0bbbbbbbbbbbbbbb2", "subnet-0bbbbbbbbbbbbbbb3"]
  }
}

dependency "cluster" {
  config_path = "${get_terragrunt_dir()}/../ecs-cluster"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    cluster_arn  = "arn:aws:ecs:${local.env.region}:${local.env.account_id}:cluster/tabz-${local.env.environment}"
    cluster_name = "tabz-${local.env.environment}"
  }
}

dependency "alb" {
  config_path = "${get_terragrunt_dir()}/../alb"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    listener_arn      = "arn:aws:elasticloadbalancing:${local.env.region}:${local.env.account_id}:listener/app/tabz-${local.env.environment}/0123456789abcdef/0123456789abcdef"
    alb_arn_suffix    = "app/tabz-${local.env.environment}/0123456789abcdef"
    security_group_id = "sg-0aaaaaaaaaaaaaaa1"
  }
}

dependency "redis" {
  config_path = "${get_terragrunt_dir()}/../redis"

  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
  mock_outputs = {
    primary_endpoint  = "master.tabz-${local.env.environment}.abcdef.euc1.cache.amazonaws.com"
    port              = 6379
    security_group_id = "sg-0ccccccccccccccc1"
    auth_secret_arn   = "arn:aws:secretsmanager:${local.env.region}:${local.env.account_id}:secret:tabz-${local.env.environment}/redis-AbCdEf"
  }
}

inputs = {
  name         = local.name
  cluster_arn  = dependency.cluster.outputs.cluster_arn
  cluster_name = dependency.cluster.outputs.cluster_name
  vpc_id       = dependency.vpc.outputs.vpc_id
  subnet_ids   = dependency.vpc.outputs.private_subnets

  # Unprivileged nginx listens on 8080 and only writes to /tmp -> read-only root fs works.
  container_name  = "nginx"
  container_image = "nginxinc/nginx-unprivileged:1.27-alpine"
  container_port  = 8080
  writable_paths  = ["/tmp"]

  environment = {
    APP_ENV    = local.env.environment
    REDIS_HOST = dependency.redis.outputs.primary_endpoint
    REDIS_PORT = tostring(dependency.redis.outputs.port)
    REDIS_TLS  = "true"
  }

  # THE secret: one Secrets Manager secret, injected by the ECS agent at task start.
  # Only the auth_token JSON key is exposed; the execution role may read only this ARN.
  secrets = {
    REDIS_AUTH_TOKEN = {
      arn = dependency.redis.outputs.auth_secret_arn
      key = "auth_token"
    }
  }

  sidecars = {
    redis-probe = {
      image      = "public.ecr.aws/docker/library/redis:7.2-alpine"
      essential  = false
      entrypoint = ["/bin/sh", "-c"]
      command    = [local.redis_probe_script]
      environment = {
        REDIS_HOST = dependency.redis.outputs.primary_endpoint
        REDIS_PORT = tostring(dependency.redis.outputs.port)
      }
      secrets = ["REDIS_AUTH_TOKEN"]
    }
  }

  load_balancer = {
    listener_arn      = dependency.alb.outputs.listener_arn
    security_group_id = dependency.alb.outputs.security_group_id
    arn_suffix        = dependency.alb.outputs.alb_arn_suffix
    priority          = 100
    path_patterns     = ["/*"]
    health_check      = { path = "/" }
  }

  # Opens exactly tcp/6379 service-SG -> redis-SG (egress on ours, ingress on theirs).
  egress_to_security_groups = {
    redis = {
      security_group_id = dependency.redis.outputs.security_group_id
      port              = dependency.redis.outputs.port
      description       = "Redis (TLS)"
    }
  }
}
