resource "aws_instance" "app_server1" {
  ami           = var.app_server_ami
  instance_type = var.app_server_instance_type
  availability_zone = var.app_server1_az
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id     = element(aws_subnet.private_subnet_ids.value, 0)
  security_groups = [
    aws_security_group.ec2_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              apt-get update -y
              apt-get install -y python3 python3-pip unzip awscli
              cd /home/ubuntu
              aws s3 cp s3://${var.s3_bucket_name}/${var.app_file_name}.
              unzip ${var.app_file_name}
              cd ${var.app_folder_name}
              pip3 install -r requirements.txt
              chmod +x scripts/install_dependencies.sh scripts/start_app.sh
            ./scripts/install_dependencies.sh
            ./scripts/start_app.sh
              EOF
}

resource "aws_instance" "app_server2" {
  ami           = var.app_server_ami
  instance_type = var.app_server_instance_type
  availability_zone = var.app_server2_az
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id     = element(aws_subnet.private_subnet_ids.value, 1)
  security_groups = [
    aws_security_group.ec2_sg.id
  ]

  user_data = <<-EOF
              #!/bin/bash
              exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
              apt-get update -y
              apt-get install -y python3 python3-pip unzip awscli
              cd /home/ubuntu
              aws s3 cp s3://${var.s3_bucket_name}/${var.app_file_name}.
              unzip ${var.app_file_name}
              cd ${var.app_folder_name}
              pip3 install -r requirements.txt
              chmod +x scripts/install_dependencies.sh scripts/start_app.sh
            ./scripts/install_dependencies.sh
            ./scripts/start_app.sh
              EOF
}