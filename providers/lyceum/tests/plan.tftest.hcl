# Test de plan mocké (aucun appel à l'API Lyceum).
mock_provider "restapi" {}

variables {
  hardware_profile    = "test-profile"
  gpu_count           = 2
  ssh_public_key_path = "../../tests/fixtures/ssh_key.pub"
}

run "vm_wiring" {
  command = plan

  assert {
    condition     = jsondecode(restapi_object.vm.data).hardware_profile == var.hardware_profile
    error_message = "Le hardware_profile ne correspond pas à la variable."
  }

  assert {
    condition     = jsondecode(restapi_object.vm.data).instance_specs.gpu_count == var.gpu_count
    error_message = "gpu_count devrait être transmis dans instance_specs."
  }
}
