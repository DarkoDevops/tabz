# Environment-wide settings for DEV. Replace account_id with the real dev account.
locals {
  environment = "dev"
  account_id  = "111111111111"
  region      = "eu-central-1"
  azs         = ["eu-central-1a", "eu-central-1b"]
  vpc_cidr    = "10.10.0.0/16"
}
