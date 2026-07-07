########################################
# Provider Vast.ai
#
# La clé API est lue en priorité depuis VASTAI_API_KEY.
# On ne la met dans un .tfvars qu'en dernier recours.
########################################

provider "vastai" {
  api_key = var.api_key
}

locals {
  # Réutilise la logique métier partagée (mode conteneur : ollama pull).
  onstart = "export OLLAMA_MODEL='${var.ollama_model}'\n${file("${path.module}/../../common/bootstrap.sh")}"
}

########################################
# Sélection de l'offre GPU la moins chère du marketplace
########################################

data "vastai_gpu_offers" "sel" {
  gpu_name           = var.gpu_name
  num_gpus           = var.num_gpus
  gpu_ram_gb         = var.gpu_ram_gb_min
  max_price_per_hour = var.max_price
  order_by           = "price"
  limit              = 5
}

########################################
# Clé SSH (créée depuis la clé publique locale) — requise pour le tunnel
########################################

resource "vastai_ssh_key" "mykey" {
  ssh_key = file(pathexpand(var.ssh_public_key_path))
}

########################################
# Instance GPU exécutant directement Open WebUI + Ollama
#
# Le provider n'expose pas d'IP/port HTTP public : l'accès se fait par
# tunnel SSH (voir outputs). Pas de Nginx.
########################################

resource "vastai_instance" "gpu" {
  offer_id    = data.vastai_gpu_offers.sel.most_affordable.id
  image       = "ghcr.io/open-webui/open-webui:ollama"
  disk_gb     = var.disk_gb
  label       = var.label
  use_ssh     = true
  ssh_key_ids = [vastai_ssh_key.mykey.id]

  env = {
    OLLAMA_MODEL = var.ollama_model
  }

  onstart = local.onstart
}
