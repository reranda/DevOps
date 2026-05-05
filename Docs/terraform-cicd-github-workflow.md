# GitHub Workflow for Terraform CI/CD

### Prerequisits:
1. Terraform installation
2. AWS CLI installation
3. Local GIT installation
4. GitHub Account
5. AWS IAM access keys

In this document, all the configurations will be done on Windows 11 computer. Same steps can be applied for the set up in a Linux too.

### Set up new Git project
1. Create a new GitHub project `DevOps-Home-Lab`.
2. Clone it into local computer:
```
PS D:\Learning_Projects> git clone https://github.com/reranda/DevOps-Home-Lab.git`.
```
2. Create following folder structure:
```
DevOps-Home-Lab/terraform-cicd-practice/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
│
└── .github/
    └── workflows/
        └── terraform.yml
```
3. Create `terraform-cicd-practice` folder inside the new Git repo and add the following Terraform codes:
##### `provider.tf`
```
terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket       = "bvs-terraform-state-05052026"
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
```

This section is important because GutHub action runner is temporary, which means it starts, run the job, and disappears. So your state is gone. When you run the code next time, resources will be redeployed by creating duplicate. To avoid this, Terraform will be stored on a S3 bucket.

```
backend "s3" {
    bucket       = "bvs-terraform-state-05052026"
    key          = "terraform-cicd-practice/dev/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
}
```

##### `variables.tf`
```
variable "aws_reagion" {
  description = "AWS region that deployment is done"
  type        = string
  default     = "eu-west-2"
}

variable "bucket_name" {
  description = "AWS bucket name"
  type        = string
  default     = "bvs-terra-remote-05052026"
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
```

#### `main.tf`
```
resource "aws_s3_bucket" "demo_bucket" {
  bucket = var.bucket_name

  tags = {
    Name        = "${var.project_name}-${var.bucket_name}"
    Environment = var.environment
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name        = "${var.project_name}-public-subnet"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}
```

#### `outputs.tf`
```
output "bucket_name" {
  value = aws_s3_bucket.demo_bucket.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.demo_bucket.arn
}
```

4. Create `terraform-backend-bootstrap` folder inside the Git repo and add the following Terraform codes. Folder structure would be like below.
```
DevOps-Home-Lab/
│
├── terraform-cicd-practice/
│   ├── main.tf
│   ├── provider.tf
│   ├── variables.tf
│   └── outputs.tf
│
└── terraform-backend-bootstrap/
    ├── provider.tf
    ├── variables.tf
    ├── main.tf
    └── outputs.tf
```

#### `terraform-backend-bootstrap/provider.tf`
```
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

#### `terraform-backend-bootstrap/variables.tf`
```
variable "aws_region" {
  description = "The AWS region to deploy the backend resources in."
  type        = string
  default     = "eu-west-2"
}

variable "backend_bucket_name" {
  description = "S3 bucket name for storing Terraform state"
  type        = string
  default     = "bvs-terraform-state-05052026"
}
```

#### `terraform-backend-bootstrap/main.tf`
```
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.backend_bucket_name

  tags = {
    Name        = var.backend_bucket_name
    Environment = "shared"
    Purpose     = "terraform-remote-state"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

#### `terraform-backend-bootstrap/outputs.tf`
```
output "backend_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "backend_bucket_arn" {
  value = aws_s3_bucket.terraform_state.arn
}
```
