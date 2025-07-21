variable "region" {
  description = "AWS region"
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
}

variable "volume_size" {
  description = "Taille du disque root (en Go)"
  type        = number
}

variable "key_name" {
  description = "Nom de la clé SSH EC2"
  type        = string
}

variable "instance_name" {
  description = "Nom de l'instance"
  type        = string
}

