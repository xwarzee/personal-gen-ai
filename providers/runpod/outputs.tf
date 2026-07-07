output "pod_id" {
  description = "Identifiant du pod RunPod"
  value       = runpod_pod.gpu.id
}

output "https_url" {
  description = "URL HTTPS d'Open WebUI via le proxy natif RunPod"
  value       = "https://${runpod_pod.gpu.id}-${var.web_port}.proxy.runpod.net"
}
