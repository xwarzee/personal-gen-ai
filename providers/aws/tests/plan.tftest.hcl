# Test de plan mocké (aucun appel à AWS ; variables issues de terraform.tfvars).
mock_provider "aws" {}
mock_provider "tls" {}

# Fixe l'AMI résolue par la data source (mockée).
override_data {
  target = data.aws_ami.deep_learning_gpu
  values = {
    id = "ami-0mockdeeplearning"
  }
}

run "instance_wiring" {
  command = plan

  assert {
    condition     = aws_instance.gpu_instance.instance_type == var.instance_type
    error_message = "Le type d'instance ne correspond pas à la variable."
  }

  assert {
    condition     = aws_instance.gpu_instance.ami == "ami-0mockdeeplearning"
    error_message = "L'AMI devrait provenir de la data source aws_ami."
  }

  assert {
    condition     = strcontains(aws_instance.gpu_instance.user_data, "open-webui")
    error_message = "Le user_data devrait lancer Open WebUI."
  }

  assert {
    condition = (
      aws_ebs_volume.ollama.size == var.ollama_volume_size &&
      aws_ebs_volume.openwebui.size == var.openwebui_volume_size &&
      aws_ebs_volume.ollama.encrypted &&
      aws_ebs_volume.openwebui.encrypted
    )
    error_message = "Les volumes EBS persistants doivent être dimensionnés via variables et chiffrés."
  }

  assert {
    condition = (
      strcontains(aws_instance.gpu_instance.user_data, "OLLAMA_DATA_DIR=\"/mnt/ollama\"") &&
      strcontains(aws_instance.gpu_instance.user_data, "OPENWEBUI_DATA_DIR=\"/mnt/openwebui\"")
    )
    error_message = "Le user_data devrait brancher le bootstrap sur les volumes persistants."
  }
}
