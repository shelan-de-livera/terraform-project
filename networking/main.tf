# VPC
resource "aws_vpc" "app_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Public Subnets
resource "aws_subnet" "public_subnet1" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = var.public_subnet1_cidr_block
  availability_zone = var.public_subnet1_az
}

resource "aws_subnet" "public_subnet2" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = var.public_subnet2_cidr_block
  availability_zone = var.public_subnet2_az
}

# Private Subnets
resource "aws_subnet" "private_subnet1" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = var.private_subnet1_cidr_block
  availability_zone = var.private_subnet1_az
}

resource "aws_subnet" "private_subnet2" {
  vpc_id     = aws_vpc.app_vpc.id
  cidr_block = var.private_subnet2_cidr_block
  availability_zone = var.private_subnet2_az
}

# Internet Gateway
resource "aws_internet_gateway" "app_internet_gateway" {
  vpc_id = aws_vpc.app_vpc.id
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "app_nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet1.id
}

# Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_internet_gateway.id
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.app_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.app_nat_gateway.id
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_subnet1_assoc" {
  subnet_id      = aws_subnet.public_subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet2_assoc" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet1_assoc" {
  subnet_id      = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet2_assoc" {
  subnet_id      = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.app_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"

  route_table_ids = [
    aws_route_table.private_route_table.id
  ]
}