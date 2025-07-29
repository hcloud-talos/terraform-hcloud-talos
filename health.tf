# The cluster should be healthy after cilium is installed
# It's actually not helpful because of https://github.com/siderolabs/talos/issues/7967#issuecomment-2003751512
#data "talos_cluster_health" "this" {
#  depends_on           = [data.helm_template.cilium]
#  client_configuration = data.talos_client_configuration.this.client_configuration
#  endpoints            = local.control_plane_public_ipv4_list
#  control_plane_nodes  = local.control_plane_private_ipv4_list
#  worker_nodes         = local.worker_private_ipv4_list
#}

locals {
  talos_health_endpoint = var.enable_ipv6_only ? "https://${local.control_plane_public_ipv6_list[0]}1:${local.api_port_k8s}": "https://${local.control_plane_public_ipv4_list[0]}:${local.api_port_k8s}"
}

data "http" "talos_health" {
  count    = var.control_plane_count > 0 ? 1 : 0
  url      = "${local.talos_health_endpoint}/version"
  insecure = true
  retry {
    attempts     = 1
    min_delay_ms = 5000
    max_delay_ms = 5000
  }
  depends_on = [talos_machine_bootstrap.this]
}
