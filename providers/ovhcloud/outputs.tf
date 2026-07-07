output "public_ip" {
  description = "Adresse IP publique de l'instance OVHcloud"
  value       = openstack_compute_instance_v2.gpu.access_ip_v4
}

output "https_url" {
  description = "URL HTTPS d'Open WebUI (certificat auto-signé)"
  value       = "https://${openstack_compute_instance_v2.gpu.access_ip_v4}"
}
