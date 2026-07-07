########################################
# Provider RunPod
#
# La clé API est lue en priorité depuis la variable d'environnement
# RUNPOD_API_KEY. On ne la met dans un .tfvars qu'en dernier recours.
########################################

provider "runpod" {
  api_key = var.api_key
}

########################################
# Pod GPU exécutant directement Open WebUI + Ollama
#
# Contrairement à AWS, on ne provisionne pas de VM/VPC : RunPod lance
# directement l'image Docker. Le HTTPS et l'authentification sont fournis
# par le proxy natif RunPod (https://<pod_id>-<port>.proxy.runpod.net),
# donc pas de Nginx à gérer ici.
########################################

resource "runpod_pod" "gpu" {
  name         = var.pod_name
  image_name   = var.image
  cloud_type   = var.cloud_type
  compute_type = "GPU"

  gpu_type_ids = var.gpu_type_ids
  gpu_count    = var.gpu_count

  # Disque éphémère du conteneur + volume persistant pour les modèles Ollama
  container_disk_in_gb = var.container_disk_gb
  volume_in_gb         = var.volume_gb
  volume_mount_path    = "/root/.ollama"

  # Port HTTP exposé -> proxifié en HTTPS par RunPod
  ports = ["${var.web_port}/http"]

  # Modèle Ollama à pré-télécharger (voir README : pull possible aussi via l'UI)
  env = {
    OLLAMA_MODEL = var.ollama_model
  }
}
