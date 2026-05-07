variable "aws_region" {
  description = "The AWS region to deploy the backend resources in."
  type        = string
  default     = "eu-west-2"
}

variable "backend_bucket_name" {
  description = "S3 bucket name for storing Terraform state"
  type        = string
  default     = "bvs-terraform-state-07052026"
}