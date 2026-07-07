output "public_ip" {
  description = "Adresse IP publique de l'instance Exoscale"
  value       = exoscale_compute_instance.gpu.public_ip_address
}

output "https_url" {
  description = "URL HTTPS d'Open WebUI (certificat auto-signé)"
  value       = "https://${exoscale_compute_instance.gpu.public_ip_address}"
}
