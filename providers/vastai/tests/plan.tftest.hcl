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
