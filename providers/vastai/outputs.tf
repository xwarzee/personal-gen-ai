output "ssh_host" {
  description = "Hôte SSH de l'instance Vast.ai"
  value       = vastai_instance.gpu.ssh_host
}

output "ssh_port" {
  description = "Port SSH de l'instance Vast.ai"
  value       = vastai_instance.gpu.ssh_port
}

output "ssh_tunnel" {
  description = "Commande à coller pour ouvrir un tunnel vers Open WebUI"
  value       = "ssh -p ${vastai_instance.gpu.ssh_port} -L 3000:localhost:8080 root@${vastai_instance.gpu.ssh_host}"
}

output "webui_url" {
  description = "URL d'Open WebUI une fois le tunnel SSH établi"
  value       = "http://localhost:3000 (via la commande ssh_tunnel)"
}
