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

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
# INTERNET GATEWAY

# Configure the internet gateway
# Attached to the VPC to provide a connection to the public internet.
# Required for public-facing resources like the NAT Gateway or Load Balancer to function.
resource "aws_internet_gateway" "app_internet_gateway" {
  vpc_id = aws_vpc.app_vpc.id

  tags = {
    Name = "app_internet_gateway"
  }
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip
# ELASTIC IP FOR NAT GATEWAY

# Elastic IP for NAT Gateway
# Allocates a static, public IP address.
# This EIP is directly associated with the NAT Gateway, providing it with a public IP for outbound internet traffic.
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat_elastic_ip"
  }
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway
# NAT GATEWAY

# Configure NAT Gateway in Public Subnet
# Deployed in the public subnet (10.0.1.0/24) and associated with the EIP.
# Allows resources in private subnets to access the internet securely (e.g., for downloading updates).
# Ensures incoming traffic to private subnets is blocked unless explicitly allowed by security groups.
resource "aws_nat_gateway" "app_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id

  tags = {
    Name = "app_nat_gateway"
  }
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
# ROUTE TABLE

# Configure the route table for the Public Subnet
# Routes all outbound traffic (0.0.0.0/0 and ::/0) to the Internet Gateway (IGW).
# Associated with the public subnet to provide internet access.
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_internet_gateway.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Configure the Private Route Table
# Routes all outbound traffic (0.0.0.0/0) to the NAT Gateway.
# Associated with private subnets to allow secure internet access for backend resources.
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_gateway.id
  }

  tags = {
    Name = "private_route_table"
  }
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
# ROUTE TABLE ASSOCIATION

# Associate the Public Subnet with the Public Route Table
# Public Subnet: Associated with the public route table to route traffic through the IGW.
resource "aws_route_table_association" "public_subnet1_assoc" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet2_assoc" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate the Private Subnets with the Private Route Table
# Private Subnets: Each is associated with the private route table to route traffic through the NAT Gateway.
resource "aws_route_table_association" "private_subnet1_assoc" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet2_assoc" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}
