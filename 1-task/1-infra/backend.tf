terraform {
  backend "s3" {
    bucket         = "mugnatto-work-ue1-tfstate"
    key            = "aws-karpenter-cluster/1-infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
