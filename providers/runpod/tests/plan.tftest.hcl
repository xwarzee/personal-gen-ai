# Test de plan mocké (aucun appel à l'API RunPod).
mock_provider "runpod" {}

run "pod_wiring" {
  command = plan

  assert {
    condition     = runpod_pod.gpu.image_name == "ghcr.io/open-webui/open-webui:ollama"
    error_message = "L'image Open WebUI attendue n'est pas configurée."
  }

  assert {
    condition     = runpod_pod.gpu.cloud_type == "COMMUNITY"
    error_message = "cloud_type devrait valoir COMMUNITY par défaut."
  }

  assert {
    condition     = contains(runpod_pod.gpu.ports, "8080/http")
    error_message = "Le port 8080/http devrait être exposé."
  }
}
