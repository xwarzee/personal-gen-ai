variable "api_key" {
  description = "Clé API Vast.ai. De préférence via VASTAI_API_KEY plutôt que dans un .tfvars."
  type        = string
  default     = null
  sensitive   = true
}

variable "gpu_name" {
  description = "Nom du modèle de GPU recherché, tel qu'exposé par l'API Vast.ai avec des espaces (ex: \"RTX 4090\", \"RTX 3090\", \"A40\")"
  type        = string
  default     = "RTX 4090"
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

variable "order_by" {
  description = "Colonne de tri des offres Vast.ai. Doit être un champ triable de l'API des bundles (ex: dph_total = prix/h)."
  type        = string
  default     = "dph_total"

  validation {
    condition     = contains(["dph_total", "dlperf_per_dphtotal", "gpu_ram"], var.order_by)
    error_message = "order_by doit valoir 'dph_total', 'dlperf_per_dphtotal' ou 'gpu_ram' (colonnes triables de l'API Vast.ai ; 'price' n'existe pas et renvoie un 400)."
  }
}
