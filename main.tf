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

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint
# VPC ENDPOINT FOR S3

# EC2 SG allows outbound HTTP traffic to S3 VPC Endpoint.
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.app_vpc.id
  service_name = "com.amazonaws.us-east-1.s3"

  route_table_ids = [
    aws_route_table.private_route_table.id
  ]
}


# =======================================================
# SECURITY GROUPS
# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group

# ALB SG allows  traffic from 0.0.0.0/0.
# ALB SG allows outbound traffic to EC2 SG.
resource "aws_security_group" "alb_sg" {
  name = "application_load_balancer_security_group"
  vpc_id      = aws_vpc.app_vpc.id

  # Inbound traffic (HTTP) from anywhere (0.0.0.0/0)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

# #   Inbound traffic (HTTPS) from anywhere (0.0.0.0/0)
#   ingress {
#     description = "HTTPS"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # security_groups = [aws_security_group.ec2_sg.id]
    cidr_blocks = ["0.0.0.0/0"]  
    # Use the Elastic IP in CIDR format (e.g., <eip_address>/32)
    # cidr_blocks = ["${aws_eip.nat_eip.public_ip}/32"] # Restrict outbound traffic to NAT Gateway
    # cidr_blocks = ["aws_eip.nat_eip.public_ip"]  # Restrict outbound traffic to NAT Gateway
    # cidr_blocks = [aws_eip.nat_eip.public_ip + "/32"] # Restrict outbound traffic to NAT Gateway
  }

  tags = {
    Name = "alb_sg"
  }
}

# EC2 SG allows inbound traffic from ALB SG.
# EC2 SG allows outbound traffic to NAT Gateway (if required).
resource "aws_security_group" "ec2_sg" {
  name = "ec2_security_group"
  vpc_id      = aws_vpc.app_vpc.id

  # Inbound traffic (HTTP) from the ALB security group
  ingress {
    description = "HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

# temporary
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

#   # Inbound traffic (HTTPS) from the ALB security group
#   ingress {
#     description    = "HTTPS"
#     from_port      = 443
#     to_port        = 443
#     protocol       = "tcp"
#     security_groups = [aws_security_group.alb_sg.id]  
#   }

  # Allow outbound traffic to the NAT Gateway (using the Elastic IP of the NAT Gateway)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    # Use the Elastic IP in CIDR format (e.g., <eip_address>/32)
    # cidr_blocks = ["${aws_eip.nat_eip.public_ip}/32"] # Restrict outbound traffic to NAT Gateway
    cidr_blocks = ["0.0.0.0/0"]  
    # cidr_blocks = ["aws_eip.nat_eip.public_ip"]  # Restrict outbound traffic to NAT Gateway
    # cidr_blocks = [aws_eip.nat_eip.public_ip + "/32"] # Restrict outbound traffic to NAT Gateway
  }

  tags = {
    Name = "ec2_sg"
  }
}


# =======================================================
# LOAD BALANCER
# =======================================================

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
# TARGET GROUP

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.app_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
# LOAD BALANCER

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_subnet1.id, 
    aws_subnet.public_subnet2.id
    # aws_subnet.private_subnet2.id
  ]  
  
  enable_deletion_protection = false

  tags = {
    Name = "app_lb"
  }
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
# LISTENER

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment
# TARGET GROUP ATTACHMENTS

# Attach EC2 Instances to Target Group
resource "aws_lb_target_group_attachment" "app_tg_attachment1" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_server1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "app_tg_attachment2" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_server2.id
  port             = 80
}


