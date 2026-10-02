include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path   = "${get_repo_root()}/live/_envcommon/alb.hcl"
  expose = true
}

inputs = {
  deletion_protection = false
}
