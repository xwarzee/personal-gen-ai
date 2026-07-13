# Test de plan mocké (aucun appel à l'API Exoscale).
mock_provider "exoscale" {}

variables {
  ssh_key_name = "test-key"
  # exoscale_template.id est optional (non computed) : le mock ne peut pas le
  # fournir. On injecte l'id via le seam de testabilité var.template_id.
  template_id = "template-mock"
}

run "instance_wiring" {
  command = plan

  assert {
    condition     = exoscale_compute_instance.gpu.type == var.instance_type
    error_message = "Le type d'instance ne correspond pas à la variable."
  }

  assert {
    condition = (
      exoscale_security_group_rule.ssh.start_port == 22 &&
      exoscale_security_group_rule.http.start_port == 80 &&
      exoscale_security_group_rule.https.start_port == 443
    )
    error_message = "Les règles ingress 22/80/443 devraient être définies."
  }

  assert {
    condition     = strcontains(exoscale_compute_instance.gpu.user_data, "nvidia-container-toolkit")
    error_message = "Le user_data devrait installer nvidia-container-toolkit."
  }

  assert {
    condition = (
      exoscale_block_storage_volume.ollama.size == var.ollama_volume_size &&
      exoscale_block_storage_volume.openwebui.size == var.openwebui_volume_size
    )
    error_message = "Les volumes Block Storage persistants doivent être créés et attachés à l'instance."
  }

  assert {
    condition = (
      strcontains(exoscale_compute_instance.gpu.user_data, "OLLAMA_DATA_DIR=\"/mnt/ollama\"") &&
      strcontains(exoscale_compute_instance.gpu.user_data, "OPENWEBUI_DATA_DIR=\"/mnt/openwebui\"")
    )
    error_message = "Le user_data devrait brancher le bootstrap sur les volumes persistants."
  }
}
