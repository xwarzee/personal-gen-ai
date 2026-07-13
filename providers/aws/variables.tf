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

variable "ollama_model" {
  description = "Modèle Ollama à pré-télécharger au démarrage (vide = aucun, récupérable via l'UI)"
  type        = string
  default     = ""
}


variable "ollama_volume_size" {
  description = "Taille du volume persistant pour les modèles Ollama (Go)"
  type        = number
  default     = 100
}

variable "openwebui_volume_size" {
  description = "Taille du volume persistant pour les conversations Open WebUI (Go)"
  type        = number
  default     = 10
}
