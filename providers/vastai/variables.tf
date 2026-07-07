variable "api_key" {
  description = "Clé API Vast.ai. De préférence via VASTAI_API_KEY plutôt que dans un .tfvars."
  type        = string
  default     = null
  sensitive   = true
}

variable "gpu_name" {
  description = "Identifiant du modèle de GPU recherché (ex: RTX_4090, RTX_3090, A40)"
  type        = string
  default     = "RTX_4090"
}

variable "num_gpus" {
  description = "Nombre de GPU"
  type        = number
  default     = 1
}

variable "gpu_ram_gb_min" {
  description = "VRAM minimale par offre (Go)"
  type        = number
  default     = 24
}

variable "max_price" {
  description = "Prix horaire maximum accepté (USD/h)"
  type        = number
  default     = 0.50
}

variable "disk_gb" {
  description = "Taille du disque de l'instance (Go)"
  type        = number
  default     = 100
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH locale (nécessaire au tunnel)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "label" {
  description = "Libellé de l'instance Vast.ai"
  type        = string
  default     = "personal-gen-ai"
}

variable "ollama_model" {
  description = "Modèle Ollama à pré-télécharger au démarrage (vide = aucun, récupérable via l'UI)"
  type        = string
  default     = ""
}
