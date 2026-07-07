locals {
  ip = try(restapi_object.vm.api_data["ip_address"], "unknown")
}

output "vm_id" {
  description = "Identifiant de la VM Lyceum"
  value       = restapi_object.vm.id
}

output "ip_address" {
  description = "Adresse IP publique de la VM"
  value       = local.ip
}

output "ssh" {
  description = "Connexion SSH à la VM (root ; à ajuster selon l'image)"
  value       = "ssh root@${local.ip}"
}

output "provision_hint" {
  description = "Installe Open WebUI + Ollama sur la VM via SSH (l'API create ne gère pas de user_data)"
  value       = "cat ../../common/bootstrap.sh | ssh root@${local.ip} 'OLLAMA_MODEL= bash -s'"
}

output "ssh_tunnel" {
  description = "Tunnel SSH vers Open WebUI (une fois provisionné en mode hôte sur le port 3000)"
  value       = "ssh -L 3000:localhost:3000 root@${local.ip}"
}

output "webui_url" {
  description = "URL d'Open WebUI une fois le tunnel SSH établi"
  value       = "http://localhost:3000 (via la commande ssh_tunnel)"
}
