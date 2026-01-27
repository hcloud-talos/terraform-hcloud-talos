check "kubeconfig_endpoint_mode_requirements" {
  assert {
    condition     = var.kubeconfig_endpoint_mode != "public_endpoint" || var.cluster_api_host != null
    error_message = "kubeconfig_endpoint_mode=public_endpoint requires cluster_api_host to be set."
  }

  assert {
    condition     = var.kubeconfig_endpoint_mode != "private_endpoint" || var.cluster_api_host_private != null
    error_message = "kubeconfig_endpoint_mode=private_endpoint requires cluster_api_host_private to be set."
  }
}

check "kubeconfig_endpoint_mode_ha_safety" {
  assert {
    condition = (
      length(var.control_plane_nodes) == 1 ||
      var.kubeconfig_endpoint_mode != "public_ip" ||
      var.enable_floating_ip
    )

    error_message = "For HA control planes (control_plane_nodes > 1), kubeconfig_endpoint_mode=public_ip requires enable_floating_ip=true. Use public_endpoint (DNS/TCP LB) if you don't want a Floating IP."
  }

  assert {
    condition = (
      length(var.control_plane_nodes) == 1 ||
      var.kubeconfig_endpoint_mode != "private_ip" ||
      var.enable_alias_ip
    )

    error_message = "For HA control planes (control_plane_nodes > 1), kubeconfig_endpoint_mode=private_ip requires enable_alias_ip=true (VIP). Use private_endpoint if you access the VIP via private DNS."
  }
}

check "cluster_endpoint_ha_safety" {
  assert {
    condition = (
      length(var.control_plane_nodes) == 1 ||
      var.enable_alias_ip ||
      var.enable_floating_ip ||
      var.cluster_api_host != null ||
      var.cluster_api_host_private != null
    )

    error_message = "For HA control planes (control_plane_nodes > 1), you must configure a stable Kubernetes API endpoint for Talos cluster_endpoint. Enable enable_alias_ip (private VIP), enable_floating_ip (public VIP), or set cluster_api_host/cluster_api_host_private (DNS/TCP LB) to an endpoint that can reach all control plane nodes."
  }
}
