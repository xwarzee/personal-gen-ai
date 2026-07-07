# Test de plan mocké (aucun appel à l'API OVH/OpenStack).
mock_provider "openstack" {}

variables {
  # Fixture (clé publique valide mais jetable, sans clé privée).
  ssh_public_key_path = "../../tests/fixtures/ssh_key.pub"
}

run "instance_wiring" {
  command = plan

  assert {
    condition     = openstack_compute_instance_v2.gpu.flavor_name == var.flavor_name
    error_message = "Le flavor GPU ne correspond pas à la variable."
  }

  assert {
    condition = (
      openstack_networking_secgroup_rule_v2.ingress["22"].port_range_min == 22 &&
      openstack_networking_secgroup_rule_v2.ingress["443"].port_range_max == 443
    )
    error_message = "Les règles ingress 22/80/443 devraient être définies."
  }

  assert {
    condition     = strcontains(openstack_compute_instance_v2.gpu.user_data, "nvidia-container-toolkit")
    error_message = "Le user_data devrait installer nvidia-container-toolkit."
  }
}
