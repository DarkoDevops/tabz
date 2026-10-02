include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/alb.hcl"
  expose = true
}

inputs = {
  deletion_protection = true
  # Set once a domain + ACM cert exist; HTTP then becomes a 301 to HTTPS automatically.
  certificate_arn = null
}
