data "helm_template" "hcloud_ccm" {
  count     = var.deploy_hcloud_ccm ? 1 : 0
  name      = "hcloud-cloud-controller-manager"
  namespace = "kube-system"

  repository   = "https://charts.hetzner.cloud"
  chart        = "hcloud-cloud-controller-manager"
  version      = var.hcloud_ccm_version
  kube_version = var.kubernetes_version

  set = [
    {
      name  = "networking.enabled"
      value = "true"
    },
    {
      name  = "networking.clusterCIDR"
      value = local.pod_ipv4_cidr
    }
  ]
}

data "kubectl_file_documents" "hcloud_ccm" {
  count   = var.deploy_hcloud_ccm ? 1 : 0
  content = data.helm_template.hcloud_ccm[0].manifest
}

resource "kubectl_manifest" "apply_hcloud_ccm" {
  for_each   = var.deploy_hcloud_ccm ? data.kubectl_file_documents.hcloud_ccm[0].manifests : {}
  yaml_body  = each.value
  apply_only = true
  depends_on = [data.http.talos_health]
}
