terraform {
   required_version = ">= 1.6.0"
 
   backend "s3" {
     bucket       = "bvs-terraform-state-07052026"
     key          = "terraform-cicd-practice/dev/terraform.tfstate"
     region       = "eu-west-2"
     encrypt      = true
     use_lockfile = true
   }
 
   required_providers {
     aws = {
       source  = "hashicorp/aws"
       version = "~> 6.0"
     }
   }
}
 
provider "aws" {
   region = var.aws_reagion
}