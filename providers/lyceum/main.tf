########################################
# Provider restapi -> API Lyceum
#
# Lyceum (GPU cloud européen) n'a pas de provider Terraform natif. On pilote
# son API REST via le provider générique restapi :
#   POST   /vms          création
#   GET    /vms/{vm_id}  statut (read)
#   DELETE /vms/{vm_id}  terminaison (destroy)
# Auth : header Authorization: Bearer <clé lk_... ou JWT>.
########################################

provider "restapi" {
  uri                  = var.api_base
  write_returns_object = true

  headers = {
    Authorization = "Bearer ${var.api_key}"
    Content-Type  = "application/json"
  }
}

########################################
# VM GPU
#
# NB : l'API create ne prend pas de user_data / image → Open WebUI n'est PAS
# installé au boot. Le provisioning se fait ensuite par SSH (voir outputs :
# on réutilise common/bootstrap.sh en mode hôte). L'accès web passe par un
# tunnel SSH (le provider n'expose pas de proxy HTTP public).
########################################

resource "restapi_object" "vm" {
  path         = var.vms_path
  id_attribute = "vm_id"

  data = jsonencode({
    name             = var.name
    hardware_profile = var.hardware_profile
    user_public_key  = file(pathexpand(var.ssh_public_key_path))
    instance_specs = {
      cpu       = var.cpu
      memory    = var.memory_gb
      disk      = var.disk_gb
      gpu_count = var.gpu_count
    }
  })
}
