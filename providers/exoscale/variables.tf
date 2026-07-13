variable "api_key" {
  description = "Clé API Exoscale. De préférence via EXOSCALE_API_KEY plutôt que dans un .tfvars."
  type        = string
  default     = null
  sensitive   = true
}

variable "api_secret" {
  description = "Secret API Exoscale. De préférence via EXOSCALE_API_SECRET plutôt que dans un .tfvars."
  type        = string
  default     = null
  sensitive   = true
}

variable "zone" {
  description = "Zone Exoscale (ex: de-fra-1, ch-gva-2, at-vie-2). Doit proposer le type GPU choisi."
  type        = string
  default     = "de-fra-1"
}

variable "instance_type" {
  description = "Type d'instance GPU (famille.taille), ex: gpu3.small (A40), gpua30.small, gpua5000.medium"
  type        = string
  default     = "gpu3.small"
}

variable "disk_size" {
  description = "Taille du disque racine en GiB (min 10)"
  type        = number
  default     = 100
}

variable "ssh_key_name" {
  description = "Nom d'une clé SSH déjà enregistrée dans le compte Exoscale"
  type        = string
}

variable "instance_name" {
  description = "Nom de l'instance"
  type        = string
  default     = "personal-gen-ai"
}

variable "template_name" {
  description = "Nom du template Linux à utiliser"
  type        = string
  default     = "Linux Ubuntu 24.04 LTS 64-bit"
}

variable "template_id" {
  description = "Force un id de template (sinon résolu via le nom). Laisser null en usage normal ; sert de seam pour les tests mockés."
  type        = string
  default     = null
}

variable "nvidia_driver_pkg" {
  description = "Paquet du driver NVIDIA à installer (cf. guide Exoscale)"
  type        = string
  default     = "nvidia-driver-570"
}

variable "ollama_model" {
  description = "Modèle Ollama à pré-télécharger au démarrage (vide = aucun, récupérable via l'UI)"
  type        = string
  default     = ""
}

variable "ollama_volume_size" {
  description = "Taille du volume Block Storage pour Ollama (Go)"
  type        = number
  default     = 100
}

variable "openwebui_volume_size" {
  description = "Taille du volume Block Storage pour Open WebUI (Go)"
  type        = number
  default     = 10
}
