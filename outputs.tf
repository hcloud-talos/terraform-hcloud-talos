output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

output "talos_machine_configuration_example_control_plane" {
  value     = data.talos_machine_configuration.control_plane[0].machine_configuration
  sensitive = true
}

output "talos_machine_configuration_example_worker" {
  value     = data.talos_machine_configuration.worker[0].machine_configuration
  sensitive = true
}
