########################################
# Provider Exoscale
#
# Les identifiants sont lus en priorité depuis EXOSCALE_API_KEY /
# EXOSCALE_API_SECRET. On ne les met dans un .tfvars qu'en dernier recours.
########################################

provider "exoscale" {
  key    = var.api_key
  secret = var.api_secret
}

locals {
  # Fragments partagés avec la cible AWS (voir ../../common/)
  bootstrap = file("${path.module}/../../common/bootstrap.sh")
  nginx     = file("${path.module}/../../common/nginx-https.sh")

  # Cloud-init : Docker + drivers NVIDIA (absents du template) + Open WebUI + Nginx HTTPS
  user_data = <<-EOF
    #!/bin/bash
    set -eux

    # --- Base ---
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

    # --- Docker ---
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable docker
    systemctl start docker

    # --- Drivers NVIDIA + nvidia-container-toolkit (guide Exoscale) ---
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y ${var.nvidia_driver_pkg} nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker || true
    modprobe nvidia || true
    systemctl restart docker

    # --- Montage des volumes persistants ---
    # Attendre que les volumes soient disponibles
    for vol in vdb vdc; do
      for i in $(seq 1 30); do
        if lsblk /dev/$vol >/dev/null 2>&1; then break; fi
        sleep 2
      done
    done

    # Formater et monter le volume Ollama
    if ! blkid /dev/vdb >/dev/null 2>&1; then
      mkfs.ext4 /dev/vdb
    fi
    mkdir -p /mnt/ollama
    mount /dev/vdb /mnt/ollama
    chown -R root:root /mnt/ollama
    ln -sf /mnt/ollama /root/.ollama

    # Formater et monter le volume Open WebUI
    if ! blkid /dev/vdc >/dev/null 2>&1; then
      mkfs.ext4 /dev/vdc
    fi
    mkdir -p /mnt/openwebui
    mount /dev/vdc /mnt/openwebui
    chown -R root:root /mnt/openwebui
    ln -sf /mnt/openwebui /app/backend/data

    # Ajouter au fstab
    echo "/dev/vdb /mnt/ollama ext4 defaults,nofail 0 2" >> /etc/fstab
    echo "/dev/vdc /mnt/openwebui ext4 defaults,nofail 0 2" >> /etc/fstab

    # --- Bootstrap partagé : conteneur Open WebUI (--gpus all) + pull modèle ---
    export OLLAMA_MODEL="${var.ollama_model}"
    ${local.bootstrap}

    # --- Nginx HTTPS auto-signé (fragment partagé) ---
    ${local.nginx}
  EOF
}

########################################
# Security group : SSH + HTTP(S)
########################################

resource "exoscale_security_group" "ai" {
  name = "allow-ssh-https"
}

resource "exoscale_security_group_rule" "ssh" {
  security_group_id = exoscale_security_group.ai.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = "0.0.0.0/0"
  start_port        = 22
  end_port          = 22
}

resource "exoscale_security_group_rule" "http" {
  security_group_id = exoscale_security_group.ai.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = "0.0.0.0/0"
  start_port        = 80
  end_port          = 80
}

resource "exoscale_security_group_rule" "https" {
  security_group_id = exoscale_security_group.ai.id
  type              = "INGRESS"
  protocol          = "TCP"
  cidr              = "0.0.0.0/0"
  start_port        = 443
  end_port          = 443
}


########################################
# Persistent Block Storage Volumes
########################################

resource "exoscale_block_storage_volume" "ollama" {
  zone = var.zone
  name = "${var.instance_name}-ollama"
  size = var.ollama_volume_size
}

resource "exoscale_block_storage_volume" "openwebui" {
  zone = var.zone
  name = "${var.instance_name}-openwebui"
  size = var.openwebui_volume_size
}
########################################
# Template Ubuntu + instance GPU
########################################

data "exoscale_template" "ubuntu" {
  zone = var.zone
  name = var.template_name
}

resource "exoscale_compute_instance" "gpu" {
  zone               = var.zone
  name               = var.instance_name
  template_id        = coalesce(var.template_id, data.exoscale_template.ubuntu.id)
  type               = var.instance_type
  disk_size          = var.disk_size
  ssh_keys           = [var.ssh_key_name]
  block_storage_volume_ids = [exoscale_block_storage_volume.ollama.id, exoscale_block_storage_volume.openwebui.id]
  security_group_ids = [exoscale_security_group.ai.id]
  user_data          = local.user_data
}
