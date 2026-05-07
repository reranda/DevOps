variable "aws_reagion" {
   description = "AWS region that deployment is done"
   type        = string
   default     = "eu-west-2"
}
 
variable "bucket_name" {
   description = "AWS bucket name"
   type        = string
   default     = "bvs-terra-remote-07052026"
}
 
variable "project_name" {
   description = "BVS Terraform deployment"
   type        = string
   default     = "bvs-terraform-cicd"
}
 
variable "environment" {
   description = "Deployment environment"
   type        = string
   default     = "dev"
}