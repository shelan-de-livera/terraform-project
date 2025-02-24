variable "app_server_ami" {
  type = string
  default = "ami-0e2c8caa4b6378d8c"
}

variable "app_server_instance_type" {
  type = string
  default = "t3.micro"
}

variable "app_server1_az" {
  type = string
  default = "us-east-1a"
}

variable "key_name" {}

variable "app_server2_az" {
  type = string
  default = "us-east-1b"
}

variable "s3_bucket_name" {}

variable "app_file_name" {
  type = string
  default = "my-flask-app.zip"
}

variable "app_folder_name" {
  type = string
  default = "my-flask-app"
}