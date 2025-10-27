terraform {
  backend "s3" {
    bucket         = "mugnatto-work-ue1-tfstate"
    key            = "aws-karpenter-cluster/3-karpenter/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
