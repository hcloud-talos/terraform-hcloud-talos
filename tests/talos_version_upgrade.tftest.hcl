# Verifies that bumping talos_version regenerates machine configuration for scale-up nodes
# without forcing replacement of existing (immutable) hcloud_server nodes.

mock_provider "hcloud" {
  # hcloud_server references these ids as Number-typed attributes; the default random
  # alphanumeric mock id is not numeric, so pin numeric-looking ids for those types.
  mock_resource "hcloud_placement_group" {
    defaults = { id = "123456" }
  }
  mock_resource "hcloud_ssh_key" {
    defaults = { id = "123456" }
  }
  mock_resource "hcloud_primary_ip" {
    defaults = { id = "123456" }
  }
}
mock_provider "talos" {
  # local.kubeconfig_data base64-decodes these fields; the default random mock string isn't valid base64.
  mock_resource "talos_cluster_kubeconfig" {
    defaults = {
      kubernetes_client_configuration = {
        ca_certificate     = "dGVzdA=="
        client_certificate = "dGVzdA=="
        client_key         = "dGVzdA=="
      }
    }
  }
}
mock_provider "http" {}
mock_provider "kubectl" {}
mock_provider "helm" {}

override_data {
  target = data.hcloud_location.selected
  values = {
    id           = 1
    name         = "fsn1"
    description  = "Falkenstein DC Park 1"
    network_zone = "eu-central"
    city         = "Falkenstein"
    country      = "DE"
    latitude     = 50.47612
    longitude    = 12.370071
  }
}

override_data {
  target = data.hcloud_locations.all
  values = {
    names = ["fsn1", "nbg1", "hel1", "ash", "hil", "sin"]
  }
}

variables {
  hcloud_token             = "test-token"
  cluster_name             = "test-cluster"
  location_name            = "fsn1"
  kubernetes_version       = "1.35.0"
  disable_arm              = true
  talos_image_id_x86       = "123456"
  network_id               = "123456"
  firewall_id              = "123456"
  kubeconfig_endpoint_mode = "private_ip" # avoids requiring enable_floating_ip for the HA control_plane_nodes below
  firewall_use_current_ip  = false

  deploy_cilium                   = false
  deploy_hcloud_ccm               = false
  deploy_prometheus_operator_crds = false

  control_plane_nodes = [
    { id = 1, type = "cx22" },
    { id = 2, type = "cx22" },
    { id = 3, type = "cx22" },
  ]
  worker_nodes = [
    { id = 1, type = "cx22" },
  ]
}

run "bootstrap_v1" {
  command = apply

  variables {
    talos_version = "v1.12.2"
  }

  assert {
    condition     = talos_machine_secrets.this.talos_version == "v1.12.2"
    error_message = "talos_machine_secrets.this.talos_version must match var.talos_version"
  }
}

run "bump_talos_version" {
  command = plan

  variables {
    talos_version = "v1.13.0"
  }

  assert {
    condition     = talos_machine_secrets.this.talos_version == "v1.13.0"
    error_message = "talos_machine_secrets.this.talos_version must reflect the bumped talos_version"
  }

  assert {
    condition     = data.talos_machine_configuration.control_plane["control-plane-1"].talos_version == "v1.13.0"
    error_message = "scale-up config for new control plane nodes must use the bumped talos_version"
  }

  assert {
    condition     = data.talos_machine_configuration.worker["worker-1"].talos_version == "v1.13.0"
    error_message = "scale-up config for new worker nodes must use the bumped talos_version"
  }

  # hcloud_server ignore_changes must still shield existing nodes: bumping talos_version must not replace them.
  assert {
    condition     = output.talos_control_plane_ids["control-plane-1"] == run.bootstrap_v1.talos_control_plane_ids["control-plane-1"]
    error_message = "control plane node must not be replaced when talos_version changes"
  }

  assert {
    condition     = output.talos_worker_ids["worker-1"] == run.bootstrap_v1.talos_worker_ids["worker-1"]
    error_message = "worker node must not be replaced when talos_version changes"
  }
}
