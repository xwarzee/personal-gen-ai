variable "region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "EC2 Instance type (ex: g4dn.4xlarge)"
  type        = string
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
}

variable "key_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "instance_name" {
  description = "EC2 instance name tag"
  type        = string
}

