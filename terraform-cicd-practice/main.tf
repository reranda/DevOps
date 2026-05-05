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