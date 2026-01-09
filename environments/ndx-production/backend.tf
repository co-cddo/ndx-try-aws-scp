terraform {
  backend "s3" {
    bucket         = "ndx-terraform-state-955063685555"
    key            = "scp-overrides/terraform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "ndx-terraform-locks"
  }
}
