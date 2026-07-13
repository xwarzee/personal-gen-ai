########################################
# Provider OpenStack (OVH Public Cloud)
#
# OVH Public Cloud est basé sur OpenStack. L'authentification se fait via les
# variables d'environnement OS_* (fichier "OpenStack RC" / application
# credentials téléchargé depuis l'espace client OVH). La région est fixée ici.
########################################

provider "openstack" {
  region = var.region
}

locals {
  # Fragments partagés avec les autres cibles « vraie VM » (voir ../../common/)
  bootstrap = file("${path.module}/../../common/bootstrap.sh")
  nginx     = file("${path.module}/../../common/nginx-https.sh")

  # Cloud-init : Docker + drivers NVIDIA (absents des images standard) + Open WebUI + Nginx HTTPS
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

    # --- Drivers NVIDIA + nvidia-container-toolkit ---
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
# Clé SSH (keypair créé depuis la clé publique locale)
########################################

resource "openstack_compute_keypair_v2" "key" {
  name       = "${var.instance_name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

########################################
# Security group : SSH + HTTP(S)
########################################

resource "openstack_networking_secgroup_v2" "ai" {
  name        = "allow-ssh-https"
  description = "Allow SSH and HTTP(S) traffic"
}

locals {
  ingress_ports = [22, 80, 443]
}

resource "openstack_networking_secgroup_rule_v2" "ingress" {
  for_each          = toset([for p in local.ingress_ports : tostring(p)])
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = tonumber(each.value)
  port_range_max    = tonumber(each.value)
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.ai.id
}


########################################
# Persistent Cinder Volumes
########################################

resource "openstack_blockstorage_volume_v3" "ollama" {
  name        = "${var.instance_name}-ollama"
  size        = var.ollama_volume_size
  volume_type = "ceph-ext4"
}

resource "openstack_blockstorage_volume_v3" "openwebui" {
  name        = "${var.instance_name}-openwebui"
  size        = var.openwebui_volume_size
  volume_type = "ceph-ext4"
}

resource "openstack_compute_volume_attach_v2" "ollama" {
  instance_id = openstack_compute_instance_v2.gpu.id
  volume_id   = openstack_blockstorage_volume_v3.ollama.id
}

resource "openstack_compute_volume_attach_v2" "openwebui" {
  instance_id = openstack_compute_instance_v2.gpu.id
  volume_id   = openstack_blockstorage_volume_v3.openwebui.id
}
########################################
# Instance GPU
########################################

resource "openstack_compute_instance_v2" "gpu" {
  name            = var.instance_name
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.key.name
  security_groups = [openstack_networking_secgroup_v2.ai.name]
  user_data       = local.user_data

  network {
    name = var.network_name
  }
}
