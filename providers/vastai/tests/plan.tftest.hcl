# Test de plan mocké (aucun appel à l'API Vast.ai).
mock_provider "vastai" {
  # most_affordable.id est computed : on le fixe (>= 1, contrainte du schéma).
  mock_data "vastai_gpu_offers" {
    defaults = {
      most_affordable = { id = 12345 }
    }
  }
}

variables {
  # Fixture (clé publique valide mais jetable, sans clé privée).
  ssh_public_key_path = "../../tests/fixtures/ssh_key.pub"
}

run "instance_wiring" {
  # apply (sur providers mockés) pour que ssh_host/ssh_port soient connus
  # et que l'output ssh_tunnel soit évaluable.
  command = apply

  assert {
    condition     = vastai_instance.gpu.image == "ghcr.io/open-webui/open-webui:ollama"
    error_message = "L'image Open WebUI attendue n'est pas configurée."
  }

  assert {
    condition     = strcontains(output.ssh_tunnel, "-L 3000:localhost:8080")
    error_message = "La commande de tunnel SSH devrait forwarder 3000 -> 8080."
  }
}

run "vllm_wiring" {
  command = apply

  variables {
    engine = "vllm"
  }

  assert {
    condition     = vastai_instance.gpu.image == "vllm/vllm-openai:latest"
    error_message = "En mode vllm, l'image de l'instance doit être vllm/vllm-openai."
  }

  assert {
    condition     = strcontains(vastai_instance.gpu.onstart, "export ENGINE='vllm'")
    error_message = "onstart doit exporter ENGINE='vllm' pour bootstrap.sh."
  }

  assert {
    condition     = strcontains(output.ssh_tunnel, "-L 8000:localhost:8000")
    error_message = "En mode vllm, le tunnel SSH devrait forwarder 8000 -> 8000."
  }

  assert {
    condition     = strcontains(output.endpoint_url, "/v1")
    error_message = "En mode vllm, endpoint_url doit pointer vers l'API OpenAI-compatible (/v1)."
  }
}
