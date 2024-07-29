data "helm_template" "cilium_default" {
  count     = var.cilium_values == null ? 1 : 0
  name      = "cilium"
  namespace = "kube-system"

  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version

  set {
    name  = "operator.replicas"
    value = var.control_plane_count > 1 ? 2 : 1
  }
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
    value = "127.0.0.1"
  }
  set {
    name  = "k8sServicePort"
    value = local.api_port_kube_prism
  }
  set {
    name  = "hubble.enabled"
    value = "false"
  }
  set {
    name  = "prometheus.serviceMonitor.enabled"
    value = var.cilium_enable_service_monitors ? "true" : "false"
  }
  set {
    name  = "prometheus.serviceMonitor.trustCRDsExist"
    value = var.cilium_enable_service_monitors ? "true" : "false"
  }
  set {
    name  = "operator.prometheus.serviceMonitor.enabled"
    value = var.cilium_enable_service_monitors ? "true" : "false"
  }
}

data "helm_template" "cilium_from_values" {
  count     = var.cilium_values != null ? 1 : 0
  name      = "cilium"
  namespace = "kube-system"

  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version
  values       = var.cilium_values
}

data "kubectl_file_documents" "cilium" {
  content = coalesce(
    can(data.helm_template.cilium_from_values[0].manifest) ? data.helm_template.cilium_from_values[0].manifest : null,
    can(data.helm_template.cilium_default[0].manifest) ? data.helm_template.cilium_default[0].manifest : null
  )
}

resource "kubectl_manifest" "apply_cilium" {
  for_each   = var.control_plane_count > 0 ? data.kubectl_file_documents.cilium.manifests : {}
  yaml_body  = each.value
  apply_only = true
  depends_on = [data.http.talos_health]
}


data "helm_template" "prometheus_operator_crds" {
  count        = var.deploy_prometheus_operator_crds ? 1 : 0
  chart        = "prometheus-operator-crds"
  name         = "prometheus-operator-crds"
  repository   = "https://prometheus-community.github.io/helm-charts"
  kube_version = var.kubernetes_version
}

data "kubectl_file_documents" "prometheus_operator_crds" {
  count   = var.deploy_prometheus_operator_crds ? 1 : 0
  content = data.helm_template.prometheus_operator_crds[0].manifest
}

resource "kubectl_manifest" "apply_prometheus_operator_crds" {
  for_each          = var.control_plane_count > 0 && var.deploy_prometheus_operator_crds ? data.kubectl_file_documents.prometheus_operator_crds[0].manifests : {}
  yaml_body         = each.value
  server_side_apply = true
  apply_only        = true
  depends_on        = [data.http.talos_health]
}
