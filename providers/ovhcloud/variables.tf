variable "region" {
  description = "Région OVH/OpenStack (ex: GRA11 pour A100/H100/L4/L40S ; GRA7/9/BHS5 pour V100)"
  type        = string
  default     = "GRA11"
}

variable "flavor_name" {
  description = "Flavor GPU OVH (ex: l4-90, l40s-90, a100-180, t2-45 pour V100)"
  type        = string
  default     = "l4-90"
}

variable "image_name" {
  description = "Nom de l'image OVH à utiliser"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "network_name" {
  description = "Réseau public OVH (donne une IP publique)"
  type        = string
  default     = "Ext-Net"
}

variable "instance_name" {
  description = "Nom de l'instance"
  type        = string
  default     = "personal-gen-ai"
}

variable "ssh_public_key_path" {
  description = "Chemin vers la clé publique SSH locale (keypair créé côté OVH)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "nvidia_driver_pkg" {
  description = "Paquet du driver NVIDIA à installer"
  type        = string
  default     = "nvidia-driver-570"
}

variable "ollama_model" {
  description = "Modèle Ollama à pré-télécharger au démarrage (vide = aucun, récupérable via l'UI)"
  type        = string
  default     = ""
}
