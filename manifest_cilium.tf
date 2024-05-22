data "helm_template" "cilium" {
  name      = "cilium"
  namespace = "kube-system"

  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version

  set {
    name  = "ipam.mode"
    value = "kubernetes"
  }
  set {
    name  = "routingMode"
    value = "native"
  }
  set {
    name  = "ipv4NativeRoutingCIDR"
    value = local.pod_ipv4_cidr
  }
  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }
  set {
    name  = "securityContext.capabilities.ciliumAgent"
    value = "{CHOWN,KILL,NET_ADMIN,NET_RAW,IPC_LOCK,SYS_ADMIN,SYS_RESOURCE,DAC_OVERRIDE,FOWNER,SETGID,SETUID}"
  }
  set {
    name  = "securityContext.capabilities.cleanCiliumState"
    value = "{NET_ADMIN,SYS_ADMIN,SYS_RESOURCE}"
  }
  set {
    name  = "cgroup.autoMount.enabled"
    value = "false"
  }
  set {
    name  = "cgroup.hostRoot"
    value = "/sys/fs/cgroup"
  }
  set {
    name  = "k8sServiceHost"
    value = local.local_api_host
  }
  set {
    name  = "k8sServicePort"
    value = local.cluster_api_port_kube_prism
  }
  set {
    name  = "hubble.enabled"
    value = "false"
  }
  set {
    name  = "prometheus.enabled"
    value = "true"
  }
  set {
    name  = "operator.prometheus.enabled"
    value = "true"
  }
}

data "kubectl_file_documents" "cilium" {
  content = data.helm_template.cilium.manifest
}

resource "kubectl_manifest" "apply_cilium" {
  for_each   = var.control_plane_count > 0 ? data.kubectl_file_documents.cilium.manifests : {}
  yaml_body  = each.value
  depends_on = [data.http.talos_health]
}
