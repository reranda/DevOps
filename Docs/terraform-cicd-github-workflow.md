# GitHub Workflow for Terraform CI/CD

### Prerequisits:
Following requirements needs to be ready to proceed with the following configuration.
- Terraform installation
- AWS CLI installation
- Local GIT installation
- GitHub Account
- AWS IAM access keys

In this document, all the configurations will be done on Windows 11 computer. Same steps can be applied for the set up in a Linux too.

### 1. Setting up new GitHub project
1. Create a new GitHub project `DevOps-Home-Lab`.
2. Clone it into local computer:
   ```
   PS D:\Learning_Projects> git clone https://github.com/reranda/DevOps-Home-Lab.git`.
   ```
### 2. Setting up folder structure on local Git repo
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
1. Create `terraform-cicd-practice` folder inside the new Git repo and add the following Terraform codes:
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

   This section is most important because GutHub action runner is temporary, which means it starts, runs the job, and disappears. So the deployment state will be gone. When you run the code next         time, resources will be redeployed by creating duplicates. To avoid this, Terraform will be stored the deployment state on the S3 bucket.
   The S3 backend stores state at the object path defined by key, inside the bucket defined by bucket. The `use_lockfile = true` setting enables S3-based state locking.

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
   
2. Create `terraform-backend-bootstrap` folder inside the Git repo and add the following Terraform codes. Folder structure would be like below.
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

3. Deploy the Backend-Bootstrap code
This deployment should be done prior to anyother deployments because, this will deploye the S3 bucket and this bucket is required to store state of the deployments that will be done through GitHub workflows.
   ```
   cd D:\Learning_Projects\DevOps-Home-Lab\terraform-backend-bootstrap
   terraform init
   terraform fmt -recursive
   terraform validate
   terraform plan
   terraform apply
   ```

### 3. Create GitHub action flow
1. Folder structure would be like below.
   ```
    DevOps-Home-Lab/
    │
    ├── .github/
    │   └── workflows/
    │       ├── terraform-destroy.yml
    │       └── terraform.yml
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

   Add following contents.

   #### `terraform.yml`
    ```
    name: Terraform CI/CD
    
    on:
      pull_request:
        branches:
          - main
    
      push:
        branches:
          - main
    
      workflow_dispatch:
    
    jobs:
      terraform:
        name: Terraform
        runs-on: ubuntu-latest
    
        defaults:
          run:
            working-directory: terraform-cicd-practice
    
        env:
          TF_VAR_bucket_name: bvs-terra-remote-05052026
          AWS_REGION: eu-west-2
          AWS_DEFAULT_REGION: eu-west-2
    
        steps:
          - name: Checkout repository
            uses: actions/checkout@v4
    
          - name: Setup Terraform
            uses: hashicorp/setup-terraform@v3
    
          - name: Terraform Format Check
            run: terraform fmt -check -recursive
    
          - name: Terraform Init
            run: terraform init
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    
          - name: Terraform Validate
            run: terraform validate
    
          - name: Terraform Plan
            run: terraform plan -input=false
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    
          - name: Terraform Apply
            if: github.ref == 'refs/heads/main' && github.event_name == 'push'
            run: terraform apply -auto-approve -input=false
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    ```

    #### `terraform-destroy.yml`
    ```
    name: Terraform Destroy
    
    on:
      workflow_dispatch:
    
    jobs:
      terraform-destroy:
        name: Terraform Destroy
        runs-on: ubuntu-latest
    
        defaults:
          run:
            working-directory: terraform-cicd-practice
    
        env:
          TF_VAR_bucket_name: bvs-terra-remote-05052026
          AWS_REGION: eu-west-2
          AWS_DEFAULT_REGION: eu-west-2
    
        steps:
          - name: Checkout repository
            uses: actions/checkout@v4
    
          - name: Setup Terraform
            uses: hashicorp/setup-terraform@v3
    
          - name: Terraform Init
            run: terraform init
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    
          - name: Terraform Destroy Plan
            run: terraform plan -destroy -input=false
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    
          - name: Terraform Destroy
            run: terraform destroy -auto-approve -input=false
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    ```

2. Create `.gitignore` file in the root of the Git repo.
    ```
    DevOps-Home-Lab/
    │
    ├── .github/
    │   └── workflows/
    │       ├── terraform-destroy.yml
    │       └── terraform.yml
    │
    ├── terraform-cicd-practice/
    │   ├── main.tf
    │   ├── provider.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── terraform-backend-bootstrap/
    │   ├── provider.tf
    │   ├── variables.tf
    │   ├── main.tf
    │   └── outputs.tf
    │
    └── .gitignore
    ```

    Add the file content.

    #### `.gitignore`
    ```
    # Terraform generated folders
    terraform-cicd-practice/.terraform/
    terraform-backend-bootstrap/.terraform/
    
    # Terraform state files
    terraform-cicd-practice/*.tfstate
    terraform-cicd-practice/*.tfstate.*
    terraform-backend-bootstrap/*.tfstate
    terraform-backend-bootstrap/*.tfstate.*
    
    # Terraform variable files
    terraform-cicd-practice/*.tfvars
    terraform-cicd-practice/*.tfvars.json
    terraform-backend-bootstrap/*.tfvars
    terraform-backend-bootstrap/*.tfvars.json
    
    # Crash logs
    terraform-cicd-practice/crash.log
    terraform-cicd-practice/crash.*.log
    terraform-backend-bootstrap/crash.log
    terraform-backend-bootstrap/crash.*.log
    
    # OS/editor log files
    .DS_Store
    Thumbs.db
    .vscode/
    ```

### 4. Add AWS credentials to GitHub Secrets
1. In the GitHub dashboard, go to `DevOps-Home-Lab` -> `Settings` -> `Secrets and variables` -> `Actions` Click on `New repository secret` button and create two Secrets for aws_access_key_id and         aws_secret_access_key.
   
   <img width="870" height="469" alt="image" src="https://github.com/user-attachments/assets/357f3bdf-16ef-4ce2-8625-807bf3290226" />

   <img width="880" height="472" alt="image" src="https://github.com/user-attachments/assets/17df5613-6f16-4110-8149-322365c39305" />

### 5. Commit and push
Now commit and push the changes to GitHub. It will trigger the GitHub workflow and automatically deploy the infrastructure.
   ```
   cd D:\Learning_Projects\DevOps-Home-Lab
   git add .
   git commit -m "Initial commit to initialize the workflow deployment"
   git push
   ```
### 6. Add manual approval
1. Create a GitHub environment called `dev`. Then update the workflow so the apply job waits for approval. In order to enable reviewer appoval, repository should be **Public**. Go ro `Settings` -> `Environments` -> `New environment`. Set the Name as **dev** and click `Configure environment`.
2. Now add the approver's name and click **Save protection rules**
   
   <img width="807" height="653" alt="image" src="https://github.com/user-attachments/assets/d6ddd075-8568-4899-ace0-fe6256d8cbc7" />

3. Use this improved version of `.github/workflows/terraform.yml` file.
   ```
   name: Terraform CI/CD

   on:
     pull_request:
       branches:
         - main
   
     push:
       branches:
         - main
   
     workflow_dispatch:
   
   jobs:
     terraform-plan:
       name: Terraform Plan
       runs-on: ubuntu-latest
   
       defaults:
         run:
           working-directory: terraform-cicd-practice
   
       env:
         TF_VAR_bucket_name: bvs-terra-remote-05052026
         AWS_REGION: eu-west-2
         AWS_DEFAULT_REGION: eu-west-2
   
       steps:
         - name: Checkout repository
           uses: actions/checkout@v4
   
         - name: Setup Terraform
           uses: hashicorp/setup-terraform@v3
   
         - name: Terraform Format Check
           run: terraform fmt -check -recursive
   
         - name: Terraform Init
           run: terraform init
           env:
             AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
             AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
   
         - name: Terraform Validate
           run: terraform validate
   
         - name: Terraform Plan
           run: terraform plan -input=false
           env:
             AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
             AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
   
     terraform-apply:
       name: Terraform Apply
       runs-on: ubuntu-latest
       needs: terraform-plan
   
       if: github.ref == 'refs/heads/main' && github.event_name == 'push'
   
       environment:
         name: dev
   
       defaults:
         run:
           working-directory: terraform-cicd-practice
   
       env:
         TF_VAR_bucket_name: bvs-terra-remote-05052026
         AWS_REGION: eu-west-2
         AWS_DEFAULT_REGION: eu-west-2
   
       steps:
         - name: Checkout repository
           uses: actions/checkout@v4
   
         - name: Setup Terraform
           uses: hashicorp/setup-terraform@v3
   
         - name: Terraform Init
           run: terraform init
           env:
             AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
             AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
   
         - name: Terraform Apply
           run: terraform apply -auto-approve -input=false
           env:
             AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
             AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
   ```
4. Do the same for destroy work flow. Change the following section;
   ```
   jobs:
     terraform-destroy:
       name: Terraform Destroy
       runs-on: ubuntu-latest
   ```
   replace with following code.
   ```
   jobs:
     terraform-destroy:
       name: Terraform Destroy
       runs-on: ubuntu-latest
   
       environment:
         name: dev
   ```
5. Add, commit, and push
   ```
   git add .
   git commit -m "Add manual approval for Terraform apply and destroy"
   git push
   ```
7. You will receive a mail to notify it. Also you can see the approval requests at `Actions`

### 7. Replace AWS keys with GitHub OIDC
GitHub documents recommended to use OIDC for GitHub Actions request short-lived credentials from AWS instead of storing long-lived AWS keys in GitHub Secrets. 

1. Create the GitHub OIDC provider in AWS
   This is created once per AWS account. Go to `AWS Console` -> `IAM` -> `Identity providers` -> `Add provider`.
   Select:
      - Provider type: `OpenID Connect`
      - Provider URL: `https://token.actions.githubusercontent.com`
      - Audience: `sts.amazonaws.com`
      
      <img width="1540" height="448" alt="image" src="https://github.com/user-attachments/assets/6e315cd4-e890-4b53-af5e-3481533f5904" />

      - Then click `Add provider`
2. Create an IAM role for GitHub Actions
   Go to `IAM` -> `Roles` -> `Create role`.
   Choose:
      - Trusted entity type: `Web identity`
      - Identity provider: `token.actions.githubusercontent.com`
      - Audience: `sts.amazonaws.com`
      - GitHub organization: `bvsgit-auth`

### 7. Troubleshooting
Problem:
```
PS D:\Learning_Projects\DevOps> git push 
Enumerating objects: 39, done. 
Counting objects: 100% (39/39), done. 
Delta compression using up to 8 threads Compressing objects: 100% (24/24), done. 
Writing objects: 100% (32/32), 177.27 MiB | 6.04 MiB/s, done. 
Total 32 (delta 9), reused 0 (delta 0), pack-reused 0 (from 0) 
remote: Resolving deltas: 100% (9/9), completed with 4 local objects. 
remote: error: Trace: 1cac36bf3023c644bd33087ba93b9fd10fefcfc04e7588d844373145f074b98c 
remote: error: See https://gh.io/lfs for more information. 
remote: error: File terraform-backend-bootstrap/.terraform/providers/registry.terraform.io/hashicorp/aws/6.43.0/windows_amd64/terraform-provider-aws_v6.43.0_x5.exe is 854.74 MB; this exceeds GitHub's file size limit of 100.00 MB remote: 
error: GH001: Large files detected. 
You may want to try Git Large File Storage - https://git-lfs.github.com. To https://github.com/reranda/DevOps.git 
! [remote rejected] main -> main (pre-receive hook declined) 
error: failed to push some refs to 'https://github.com/reranda/DevOps.git' 
PS D:\Learning_Projects\DevOps>
```

Resolution:
Make sure `.gitignore` file contains these lines:

```
# Terraform generated folders
terraform-cicd-practice/.terraform/
terraform-backend-bootstrap/.terraform/

# Terraform state files
terraform-cicd-practice/*.tfstate
terraform-cicd-practice/*.tfstate.*
terraform-backend-bootstrap/*.tfstate
terraform-backend-bootstrap/*.tfstate.*

# Terraform variable files
terraform-cicd-practice/*.tfvars
terraform-cicd-practice/*.tfvars.json
terraform-backend-bootstrap/*.tfvars
terraform-backend-bootstrap/*.tfvars.json

# Crash logs
terraform-cicd-practice/crash.log
terraform-cicd-practice/crash.*.log
terraform-backend-bootstrap/crash.log
terraform-backend-bootstrap/crash.*.log

# OS/editor files
.DS_Store
Thumbs.db
.vscode/
```

1. Run following commands from repo root.
```
cd D:\Learning_Projects\DevOps
```

2. Reset your unpushed commits but keep the files
```
git reset --soft origin/main
```
3. Then unstage everything
```
git reset
```
This keeps your actual files in the folder, but removes the bad local commit history that included the huge provider file.

4. Remove Terraform generated files from Git tracking
```
git rm -r --cached --ignore-unmatch terraform-backend-bootstrap/.terraform
git rm -r --cached --ignore-unmatch terraform-cicd-practice/.terraform

git rm --cached --ignore-unmatch terraform-backend-bootstrap/*.tfstate
git rm --cached --ignore-unmatch terraform-backend-bootstrap/*.tfstate.*
git rm --cached --ignore-unmatch terraform-cicd-practice/*.tfstate
git rm --cached --ignore-unmatch terraform-cicd-practice/*.tfstate.*
```

5. delete local `.terraform` folders
```
Remove-Item -Recurse -Force .\terraform-backend-bootstrap\.terraform
Remove-Item -Recurse -Force .\terraform-cicd-practice\.terraform
```

6. Add, commit, and push
```
git add .
git status
git ls-files | findstr /I ".terraform"
git ls-files | findstr /I "terraform-provider"
git ls-files | findstr /I "tfstate"
git commit -m "Cleanup stale records and retry"
git push
```
