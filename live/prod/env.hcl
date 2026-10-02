# Environment-wide settings for PROD. Replace account_id with the real prod account.
locals {
  environment = "prod"
  account_id  = "222222222222"
  region      = "eu-central-1"
  azs         = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  vpc_cidr    = "10.20.0.0/16"
}
