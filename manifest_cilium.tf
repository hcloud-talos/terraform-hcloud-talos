data "helm_template" "cilium" {
  name      = "cilium"
  namespace = "kube-system"

  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.15.2"

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
    value = local.k8s_service_host
  }
  set {
    name  = "k8sServicePort"
    value = 7445 // Uses KubePrism's default port 7445 instead of KubeAPI's 6443
  }
  set {
    name  = "hubble.enabled"
    value = "false"
  }
}

data "kubectl_file_documents" "cilium" {
  content = data.helm_template.cilium.manifest
}

resource "kubectl_manifest" "apply_cilium" {
  for_each   = data.kubectl_file_documents.cilium.manifests
  yaml_body  = each.value
  depends_on = [time_sleep.talos_settle_down]
}

resource "time_sleep" "talos_settle_down" {
  create_duration = "1m"
  depends_on      = [data.talos_cluster_kubeconfig.this]
}
