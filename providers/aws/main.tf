########################################
# Provider & Variables
########################################

provider "aws" {
  region = var.region
}

locals {
  # Fragments partagés avec les autres cibles « vraie VM » (voir ../../common/)
  bootstrap = file("${path.module}/../../common/bootstrap.sh")
  nginx     = file("${path.module}/../../common/nginx-https.sh")
}

########################################
# Network - VPC & Public subnet 
########################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "vpc-deep-learning" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-a" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-deep-learning" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "public-route-table" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

##########################################
# Security - Group allowing SSH & HTTP(S)
##########################################

resource "aws_security_group" "allow_ssh_https" {
  name        = "allow-ssh-https"
  description = "Allow SSH and HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS access"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound (pull Docker images and models)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "allow-ssh-https" }
}

########################################
# AMI Deep Learning GPU
########################################

data "aws_ami" "deep_learning_gpu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 24.04) ????????"]
  }
}

########################################
# Instance EC2 GPU + Docker + Nginx HTTPS proxy
########################################

resource "aws_instance" "gpu_instance" {
  ami                         = data.aws_ami.deep_learning_gpu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh_https.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
  }

  # IMDSv2 obligatoire (durcissement — CKV_AWS_79)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = <<-EOF
              #!/bin/bash
              set -eux

              # --- Mises à jour de base ---
              apt-get update -y
              apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

              # --- Installer Docker ---
              install -m 0755 -d /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              chmod a+r /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
                https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
                | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update -y
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

              systemctl enable docker
              systemctl start docker

              # --- Ajouter utilisateur ubuntu ---
              usermod -aG docker ubuntu

              # --- Bootstrap partagé : volumes + conteneur Open WebUI + pull modèle ---
              export OLLAMA_MODEL="${var.ollama_model}"
              ${local.bootstrap}

              # --- Nginx HTTPS auto-signé (fragment partagé) ---
              ${local.nginx}
              EOF

  tags = { Name = var.instance_name }
}

