output "ssh_host" {
  description = "Hôte SSH de l'instance Vast.ai"
  value       = vastai_instance.gpu.ssh_host
}

output "ssh_port" {
  description = "Port SSH de l'instance Vast.ai"
  value       = vastai_instance.gpu.ssh_port
}

output "ssh_tunnel" {
  description = "Commande à coller pour ouvrir le tunnel SSH vers le service"
  value = var.engine == "vllm" ? (
    "ssh -p ${vastai_instance.gpu.ssh_port} -L ${var.vllm_port}:localhost:${var.vllm_port} root@${vastai_instance.gpu.ssh_host}"
    ) : (
    "ssh -p ${vastai_instance.gpu.ssh_port} -L 3000:localhost:8080 root@${vastai_instance.gpu.ssh_host}"
  )
}

output "endpoint_url" {
  description = "URL du service une fois le tunnel SSH établi"
  value = var.engine == "vllm" ? (
    "http://localhost:${var.vllm_port}/v1 (API OpenAI-compatible, via ssh_tunnel)"
    ) : (
    "http://localhost:3000 (Open WebUI, via ssh_tunnel)"
  )
}

# Conservé pour compatibilité ; en mode vllm, pointe vers l'endpoint API.
output "webui_url" {
  description = "Alias de endpoint_url (compatibilité)"
  value = var.engine == "vllm" ? (
    "http://localhost:${var.vllm_port}/v1 (API OpenAI-compatible, via ssh_tunnel)"
    ) : (
    "http://localhost:3000 (Open WebUI, via ssh_tunnel)"
  )
}

# Exemple prêt à coller pour tester l'API OpenAI-compatible (mode vllm).
output "curl_example" {
  description = "Exemple d'appel à l'API vLLM (mode vllm ; une fois le tunnel ouvert)"
  value = var.engine == "vllm" ? (
    "curl http://localhost:${var.vllm_port}/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\":\"${var.vllm_model}\",\"messages\":[{\"role\":\"user\",\"content\":\"Bonjour\"}]}'"
    ) : (
    "(mode openwebui : ouvrez http://localhost:3000 dans le navigateur)"
  )
}
