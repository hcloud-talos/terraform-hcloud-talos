output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = length(data.talos_cluster_kubeconfig.this) > 0 ? data.talos_cluster_kubeconfig.this[0].kubeconfig_raw : null
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
