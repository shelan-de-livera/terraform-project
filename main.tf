# =======================================================
# PROVIDER
# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs
# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "" # Add Access Key
  secret_key = "" # Add Secret Key
}


# =======================================================
# CONFIGURE THE BACKEND FOR STATE STORAGE
# =======================================================
# Configure backend to store state in S3
terraform {
  backend "s3" {
    bucket = "terraform-state-and-file-bucket"  # CREATED MANUALLY
    key    = "terraform/state.tfstate" 
    region = "us-east-1"               
  }
}


# =======================================================
# NETWORKING
# =======================================================

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
# VPC

# Configure the VPC
# A single VPC with CIDR block 10.0.0.0/16 is created to house all the resources.
resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
# SUBNETS

# Public Subnet1 in AZ "us-east-1a" (for Load Balancer)
# Contains the NAT Gateway and Load Balancer.
# Associated with the public route table, allowing internet access through the Internet Gateway (IGW).
resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public_subnet1"
  }
}

resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "public_subnet2"
  }
}

# Private Subnet1 in AZ "us-east-1b"
# Houses backend resources like EC2 instances, databases, or application servers.
# Associated with the private route table, routing all external traffic through the NAT Gateway for internet access.
resource "aws_subnet" "private_subnet1" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private_subnet1"
  }
}

# Private Subnet2 in AZ "us-east-1c"
# Houses backend resources like EC2 instances, databases, or application servers.
# Associated with the private route table, routing all external traffic through the NAT Gateway for internet access.
resource "aws_subnet" "private_subnet2" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet2"
  }
}