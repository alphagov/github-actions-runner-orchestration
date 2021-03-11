terraform {
  backend "s3" {
    bucket = "co-github-actions-runner-tfstate"
    key    = "deployment.tfstate"
    region = "eu-west-2"
  }
}
