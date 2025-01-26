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

# =======================================================
# IAM
# =======================================================

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy

# IAM Policy to allow EC2 instances to access S3 bucket for both reading and writing
resource "aws_iam_policy" "ec2_s3_policy" {
  name        = "ec2_s3_access_policy"
  description = "Policy to allow EC2 instances to read/write to S3 (specifically the terraform state file)"

  # Custom policy that allows both 'GetObject' (read) and 'PutObject' (write) on the S3 bucket
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource  = [
          "arn:aws:s3:::terraform-state-and-file-bucket",                     # Bucket level for listing
          "arn:aws:s3:::terraform-state-and-file-bucket/terraform/*"            # Object level for state file
        ]
      },
      {
        Effect    = "Allow"
        Action    = "s3:PutObject"
        Resource  = "arn:aws:s3:::terraform-state-and-file-bucket/terraform/state.tfstate" # For state file write
      }
    ]
  })
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name               = "ec2_s3_access_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "codedeploy_role" {
  name               = "CodeDeployEC2Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = {
          Service = "codedeploy.amazonaws.com"
        },
        Effect    = "Allow",
        Sid       = ""
      }
    ]
  })
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
    }]
  })
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment
# Attach IAM policy to role

resource "aws_iam_role_policy_attachment" "attach_policy_to_role" {
  policy_arn = aws_iam_policy.ec2_s3_policy.arn
  role       = aws_iam_role.ec2_role.name
}

# Attach necessary policies to allow access to S3 and CodeDeploy
resource "aws_iam_role_policy_attachment" "ec2_role_codedeploy_policy1" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_role_codedeploy_policy2" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployFullAccess"
}

# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile
# IAM Instance Profile for EC2 instances

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# =======================================================
# COMPUTE RESOURCES - EC2 INSTANCES
# =======================================================
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance

resource "aws_instance" "app_server1" {
  ami           = "ami-0e2c8caa4b6378d8c"  # Replace with a valid AMI ID
  instance_type = "t3.micro"
  availability_zone = "us-east-1a"
  key_name = "aws-access-main-key"
#   iam_instance_profile = aws_iam_role.ec2_role.name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id     = aws_subnet.private_subnet1.id
  security_groups = [
    aws_security_group.ec2_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              apt-get update -y
              apt-get install -y python3 python3-pip unzip awscli
              cd /home/ubuntu
              aws s3 cp s3://terraform-state-and-file-bucket/my-flask-app.zip .
              unzip my-flask-app.zip
              cd my-flask-app
              pip3 install -r requirements.txt
              chmod +x scripts/install_dependencies.sh scripts/start_app.sh
              ./scripts/install_dependencies.sh
              ./scripts/start_app.sh
              EOF

  tags = {
    Name = "app_server1"
  }
}

resource "aws_instance" "app_server2" {
  ami           = "ami-0e2c8caa4b6378d8c"  # Replace with a valid AMI ID
  instance_type = "t3.micro"
  availability_zone = "us-east-1b"
  key_name = "aws-access-main-key"
#   iam_instance_profile = aws_iam_role.ec2_role.name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id     = aws_subnet.private_subnet2.id
  security_groups = [
    aws_security_group.ec2_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              apt-get update -y
              apt-get install -y python3 python3-pip unzip awscli
              cd /home/ubuntu
              aws s3 cp s3://terraform-state-and-file-bucket/my-flask-app.zip .
              unzip my-flask-app.zip
              cd my-flask-app
              pip3 install -r requirements.txt
              chmod +x scripts/install_dependencies.sh scripts/start_app.sh
              ./scripts/install_dependencies.sh
              ./scripts/start_app.sh
              EOF

  tags = {
    Name = "app_server2"
  }
}

# =======================================================
# CODEDEPLOY
# =======================================================

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_app
resource "aws_codedeploy_app" "flask_app" {
  name = "flask_app"
  compute_platform = "Server" # for EC2 instances
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codedeploy_deployment_group
# CodeDeploy Deployment Group
resource "aws_codedeploy_deployment_group" "my_deployment_group" {
  app_name              = aws_codedeploy_app.flask_app.name
  deployment_group_name = "MyFlaskAppDeploymentGroup"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  
  # Deployment style configuration
  deployment_style {
    deployment_type   = "IN_PLACE"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  load_balancer_info {
    elb_info {
      name = aws_lb.app_lb.name
    }
    target_group_info {
      name = aws_lb_target_group.app_tg.name
    }
  }
  
  # EC2 tag set configuration for filtering EC2 instances
  ec2_tag_set {
    ec2_tag_filter {
      key    = "Name"
      value  = "MyFlaskAppInstance"
      type   = "KEY_AND_VALUE"
    }
  }

  # Alarm configuration
  alarm_configuration {
    alarms  = ["my-alarm-name"]  # Ensure the alarm exists in CloudWatch
    enabled = true
  }

  # Outdated instances strategy
  outdated_instances_strategy = "UPDATE"
}


# =======================================================
# CODEPIPELINE Integration
# =======================================================
resource "aws_codepipeline" "flask_pipeline" {
  name     = "flask-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = "terraform-state-and-file-bucket"  # Make sure this bucket exists in the same region as CodePipeline
    type     = "S3"
  }

  # Source Stage: Pull the application code from S3
  stage {
    name = "Source"
    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["source_output"]  # This output artifact will be used by the next stage
      configuration = {
        S3Bucket    = "terraform-state-and-file-bucket"  # The S3 bucket where your source code is stored
        S3ObjectKey = "my-flask-app.zip"  # The path to your source code (e.g., a .zip file in the bucket)
      }
    }
  }

  # Deploy Stage: Deploy using CodeDeploy
  stage {
    name = "Deploy"
    action {
      name             = "DeployAction"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeploy"
      version          = "1"
      input_artifacts  = ["source_output"]  # This is the output from the Source stage
      configuration = {
        ApplicationName        = aws_codedeploy_app.flask_app.name  # Reference to the CodeDeploy application
        DeploymentGroupName    = aws_codedeploy_deployment_group.my_deployment_group.deployment_group_name  # CodeDeploy deployment group
      }
    }
  }
}
