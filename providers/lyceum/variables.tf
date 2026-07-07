variable "api_key" {
  description = "Clé API Lyceum (format lk_...) ou JWT. De préférence via LYCEUM_API_KEY passé en TF_VAR_api_key."
  type        = string
  default     = null
  sensitive   = true
}

variable "api_base" {
  description = "URL de base de l'API Lyceum"
  type        = string
  default     = "https://api.lyceum.technology/api/v2/external"
}

variable "vms_path" {
  description = "Chemin de création des VMs. À CONFIRMER : la doc OpenAPI indique POST /vms, d'autres sources /vms/create."
  type        = string
  default     = "/vms"
}

variable "hardware_profile" {
  description = "Profil matériel GPU Lyceum (À CONFIRMER via GET /vms/availability). Ex fictif : 'gpu-h100-1'."
  type        = string
}

variable "gpu_count" {
  description = "Nombre de GPU (1-8)"
  type        = number
  default     = 1
}

variable "cpu" {
  description = "vCPU"
  type        = number
  default     = 8
}

variable "memory_gb" {
  description = "Mémoire (Go)"
  type        = number
  default     = 32
}

variable "disk_gb" {
  description = "Disque (Go)"
  type        = number
  default     = 100
}

variable "name" {
  description = "Nom de la VM"
  type        = string
  default     = "personal-gen-ai"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH locale (injectée dans la VM ; requise pour le tunnel)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
