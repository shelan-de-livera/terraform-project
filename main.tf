# Configure the AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-and-file-bucket"
    key    = "terraform/state.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Networking Module
module "networking" {
  source = "./modules/networking"
}

# Security Module
module "security" {
  source = "./modules/security"
  vpc_id = module.networking.vpc_id
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  s3_bucket_name = "terraform-state-and-file-bucket"
}

# Instances Module
module "instances" {
  source = "./modules/instances"
  key_name = "aws-access-main-key"
  s3_bucket_name = "terraform-state-and-file-bucket"
  depends_on = [
    module.iam,
    module.security,
    module.networking
  ]
}

# Load Balancer Module
module "loadbalancer" {
  source = "./modules/loadbalancer"
  vpc_id = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  depends_on = [
    module.instances,
    module.security
  ]
}

# # CodeDeploy
# resource "aws_codedeploy_app" "flask_app" {
#   name = "flask_app"
#   compute_platform = "Server"
# }

# resource "aws_codedeploy_deployment_group" "my_deployment_group" {
#   app_name              = aws_codedeploy_app.flask_app.name
#   deployment_group_name = "MyFlaskAppDeploymentGroup"
#   service_role_arn      = aws_iam_role.codedeploy_role.arn

#   deployment_style {
#     deployment_type   = "IN_PLACE"
#     deployment_option = "WITH_TRAFFIC_CONTROL"
#   }

#   load_balancer_info {
#     elb_info {
#       name = aws_lb.app_lb.name
#     }
#     target_group_info {
#       name = aws_lb_target_group.app_tg.name
#     }
#   }

#   ec2_tag_set {
#     ec2_tag_filter {
#       key   = "Name"
#       value = "MyFlaskAppInstance"
#       type  = "KEY_AND_VALUE"
#     }
#   }

#   alarm_configuration {
#     alarms  = ["my-alarm-name"]
#     enabled = true
#   }

#   outdated_instances_strategy = "UPDATE"
# }

# # CodePipeline
# resource "aws_codepipeline" "flask_pipeline" {
#   name     = "flask-pipeline"
#   role_arn = aws_iam_role.codepipeline_role.arn

#   artifact_store {
#     location = "terraform-state-and-file-bucket"
#     type     = "S3"
#   }

#   stage {
#     name = "Source"
#     action {
#       name             = "SourceAction"
#       category         = "Source"
#       owner            = "AWS"
#       provider         = "S3"
#       version          = "1"
#       output_artifacts = ["source_output"]
#       configuration = {
#         S3Bucket    = "terraform-state-and-file-bucket"
#         S3ObjectKey = "my-flask-app.zip"
#       }
#     }
#   }

#   stage {
#     name = "Deploy"
#     action {
#       name             = "DeployAction"
#       category         = "Deploy"
#       owner            = "AWS"
#       provider         = "CodeDeploy"
#       version          = "1"
#       input_artifacts  = ["source_output"]
#       configuration = {
#         ApplicationName     = aws_codedeploy_app.flask_app.name
#         DeploymentGroupName = aws_codedeploy_deployment_group.my_deployment_group.deployment_group_name
#       }
#     }
#   }
# }