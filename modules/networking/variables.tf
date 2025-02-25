variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "public_subnet1_cidr_block" {
  type = string
  default = "10.0.1.0/24"
}

variable "public_subnet1_az" {
  type = string
  default = "us-east-1a"
}

variable "public_subnet2_cidr_block" {
  type = string
  default = "10.0.4.0/24"
}

variable "public_subnet2_az" {
  type = string
  default = "us-east-1b"
}

variable "private_subnet1_cidr_block" {
  type = string
  default = "10.0.2.0/24"
}

variable "private_subnet1_az" {
  type = string
  default = "us-east-1a"
}

variable "private_subnet2_cidr_block" {
  type = string
  default = "10.0.3.0/24"
}

variable "private_subnet2_az" {
  type = string
  default = "us-east-1b"
}