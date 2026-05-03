output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = local.kubeconfig
  sensitive = true
}

output "talos_client_configuration" {
  value     = data.talos_client_configuration.this
  sensitive = true
}

output "talos_machine_configurations_control_plane" {
  value     = data.talos_machine_configuration.control_plane
  sensitive = true
}

output "talos_machine_configurations_worker" {
  value     = data.talos_machine_configuration.worker
  sensitive = true
}

output "kubeconfig_data" {
  description = "Structured kubeconfig data to supply to other providers"
  value       = local.kubeconfig_data
  sensitive   = true
}

output "public_ipv4_list" {
  description = "List of public IPv4 addresses of all control plane nodes"
  value       = local.control_plane_public_ipv4_list
}

output "hetzner_network_id" {
  description = "Network ID of the Hetzner Cloud network used by the cluster"
  value       = local.network_id
}

output "network_ipv4_cidr" {
  description = "The main network CIDR that all subnets are created within"
  value       = local.network_ipv4_cidr
}

output "node_ipv4_cidr" {
  description = "The node subnet CIDR used for control plane and worker nodes"
  value       = local.node_ipv4_cidr
}

output "network_subnet_id" {
  description = "Network subnet ID (only set when the module creates the subnet)"
  value       = local.create_network ? hcloud_network_subnet.nodes[0].id : null
}

output "firewall_id" {
  description = "ID of the firewall attached to cluster nodes"
  value       = local.firewall_id
}

output "talos_worker_ids" {
  description = "Server IDs of the hetzner talos workers machines"
  value       = { for id, server in hcloud_server.workers : id => server.id }
}
