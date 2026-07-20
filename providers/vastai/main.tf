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
  # Réutilise la logique métier partagée (bootstrap.sh, auto-adaptatif). On lui
  # transmet le contexte du moteur choisi via des exports avant de l'inliner :
  # ENGINE=openwebui -> Open WebUI + Ollama ; ENGINE=vllm -> serveur vLLM.
  # (hf_token est optionnel ; vide par défaut => aucun secret dans onstart.)
  onstart = join("\n", [
    "export ENGINE='${var.engine}'",
    "export OLLAMA_MODEL='${var.ollama_model}'",
    "export VLLM_MODEL='${var.vllm_model}'",
    "export VLLM_PORT='${var.vllm_port}'",
    "export VLLM_EXTRA_ARGS='${var.vllm_extra_args}'",
    "export HF_TOKEN='${var.hf_token}'",
    file("${path.module}/../../common/bootstrap.sh"),
  ])
}

########################################
# Sélection de l'offre GPU la moins chère du marketplace
########################################

data "vastai_gpu_offers" "sel" {
  gpu_name           = var.gpu_name
  num_gpus           = var.num_gpus
  gpu_ram_gb         = var.gpu_ram_gb_min
  max_price_per_hour = var.max_price
  order_by           = var.order_by
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
  # try(...) évite l'erreur cryptique "attribute from null value" quand la
  # recherche ne renvoie aucune offre ; la precondition ci-dessous prend le
  # relais avec un message actionnable.
  offer_id = try(data.vastai_gpu_offers.sel.most_affordable.id, 0)
  # L'image DÉPEND du moteur : open-webui:ollama (UI) ou vllm/vllm-openai (API).
  # Hors ignore_changes ci-dessous : changer de moteur DOIT recréer l'instance.
  image       = var.engine == "vllm" ? var.vllm_image : "ghcr.io/open-webui/open-webui:ollama"
  disk_gb     = var.disk_gb
  label       = var.label
  use_ssh     = true
  ssh_key_ids = [vastai_ssh_key.mykey.id]

  # Attributs "creation-time" que le provider 0.3.1 laisse en unknown après
  # apply (Optional+Computed non renvoyés par l'API) -> "invalid result object
  # after apply". Les fixer explicitement les rend connus au plan et évite le bug.
  cancel_unavail  = false
  use_jupyter_lab = false
  image_login     = "" # image publique : aucune auth de registre

  env = {
    OLLAMA_MODEL = var.ollama_model
  }

  onstart = local.onstart

  # La suppression réelle est immédiate, mais le provider poll ensuite un état
  # "destroyed" que l'API actuelle ne renvoie jamais (elle répond 200
  # {"instances": null} au lieu d'un 404), gaspillant le timeout delete par
  # défaut de 5 min. On le raccourcit : `down` se termine en ~1 min, avec un
  # warning bénin "Instance Destroy Wait Failed".
  timeouts {
    delete = "60s"
  }

  lifecycle {
    # L'offre la moins chère change à chaque lecture de la data source
    # (marketplace éphémère) ; sans ceci, offer_id (ForceNew) déclencherait
    # une destruction/recréation de l'instance à chaque apply. Une fois créée,
    # on conserve l'instance et son offre d'origine.
    # offer_id : voir ci-dessus. Les trois attributs creation-time ne sont
    # jamais renvoyés par l'API (drift null perpétuel) ; on les fixe à la
    # création mais on ignore leur drift ensuite.
    ignore_changes = [offer_id, cancel_unavail, image_login, use_jupyter_lab]

    precondition {
      condition     = data.vastai_gpu_offers.sel.most_affordable != null
      error_message = "Aucune offre Vast.ai ne correspond aux critères (gpu_name=\"${var.gpu_name}\", VRAM>=${var.gpu_ram_gb_min}Go, num_gpus=${var.num_gpus}, prix<=${var.max_price}$/h). Élargissez la recherche : baissez gpu_ram_gb_min (une RTX 3090 = 24Go, une RTX 4090 = 24Go, une RTX 5090 = 32Go), augmentez max_price, ou changez gpu_name."
    }
  }
}
