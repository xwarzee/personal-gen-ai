########################################
# Provider & Variables
########################################

provider "aws" {
  region = var.region
}

########################################
# Network - VPC & Public subnet 
########################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-deep-learning" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "public-subnet-a" }
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
  instance_type                = var.instance_type
  key_name                     = var.key_name
  subnet_id                    = aws_subnet.public_a.id
  vpc_security_group_ids       = [aws_security_group.allow_ssh_https.id]
  associate_public_ip_address  = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
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

              # --- Créer volumes Docker ---
              docker volume create ollama
              docker volume create open-webui

              # --- Lancer le container Open WebUI ---
              docker run -d -p 3000:8080 --gpus=all \
                -v ollama:/root/.ollama \
                -v open-webui:/app/backend/data \
                --name open-webui \
                --restart always \
                ghcr.io/open-webui/open-webui:ollama

              # --- Installer Nginx ---
              apt-get install -y nginx openssl

              # --- Créer certificat auto-signé ---
              mkdir -p /etc/nginx/ssl
              openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/nginx/ssl/selfsigned.key \
                -out /etc/nginx/ssl/selfsigned.crt \
                -subj "/CN=openwebui.local"

              # --- Configuration Nginx pour HTTPS proxy ---
              cat << 'EOF_NGINX' > /etc/nginx/sites-available/openwebui
              server {
                  listen 443 ssl;
                  server_name _;

                  ssl_certificate     /etc/nginx/ssl/selfsigned.crt;
                  ssl_certificate_key /etc/nginx/ssl/selfsigned.key;

                  location / {
                      proxy_pass http://127.0.0.1:3000;
                      proxy_http_version 1.1;
                      proxy_set_header Upgrade $http_upgrade;
                      proxy_set_header Connection 'upgrade';
                      proxy_set_header Host $host;
                      proxy_cache_bypass $http_upgrade;
                  }
              }

              server {
                  listen 80;
                  server_name _;
                  return 301 https://$host$request_uri;
              }
              EOF_NGINX

              rm -f /etc/nginx/sites-enabled/default
              ln -s /etc/nginx/sites-available/openwebui /etc/nginx/sites-enabled/openwebui

              systemctl restart nginx
              EOF

  tags = { Name = var.instance_name }
}

