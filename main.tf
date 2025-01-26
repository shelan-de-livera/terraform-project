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


