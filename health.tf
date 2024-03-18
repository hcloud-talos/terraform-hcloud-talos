# The cluster should be healthy after cilium is installed
# It's actually not helpful because of https://github.com/siderolabs/talos/issues/7967#issuecomment-2003751512
#data "talos_cluster_health" "this" {
#  depends_on           = [data.helm_template.cilium]
#  client_configuration = data.talos_client_configuration.this.client_configuration
#  endpoints            = local.control_plane_public_ipv4_list
#  control_plane_nodes  = local.control_plane_private_ipv4_list
#  worker_nodes         = local.worker_private_ipv4_list
#}

