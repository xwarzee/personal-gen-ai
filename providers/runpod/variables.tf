variable "api_key" {
  description = "Clé API RunPod. De préférence via la variable d'environnement RUNPOD_API_KEY plutôt que dans un fichier."
  type        = string
  default     = null
  sensitive   = true
}

variable "pod_name" {
  description = "Nom du pod RunPod"
  type        = string
  default     = "personal-gen-ai"
}

variable "image" {
  description = "Image Docker à lancer"
  type        = string
  default     = "ghcr.io/open-webui/open-webui:ollama"
}

variable "cloud_type" {
  description = "Type de cloud RunPod : COMMUNITY (le moins cher) ou SECURE"
  type        = string
  default     = "COMMUNITY"
}

variable "gpu_type_ids" {
  description = "Liste ordonnée des types de GPU acceptés (voir la console RunPod pour les identifiants)"
  type        = list(string)
  default     = ["NVIDIA GeForce RTX 4090"]
}

variable "gpu_count" {
  description = "Nombre de GPU"
  type        = number
  default     = 1
}

variable "container_disk_gb" {
  description = "Disque conteneur éphémère (Go)"
  type        = number
  default     = 30
}

variable "volume_gb" {
  description = "Volume persistant monté sur /workspace (Go) — modèles Ollama et données Open WebUI"
  type        = number
  default     = 100
}

variable "web_port" {
  description = "Port interne HTTP exposé par Open WebUI (proxifié en HTTPS par RunPod)"
  type        = number
  default     = 8080
}

variable "ollama_model" {
  description = "Modèle Ollama à pré-télécharger (vide = aucun, récupérable via l'UI)"
  type        = string
  default     = ""
}
