locals {

  flux_enabled = try(var.flux.enabled, false)
  # handles var.flux == null and ensures a map keyed by name
  sops_by_name = {
    for s in try(var.flux.sops, []) :
    s.name => s
  }


  kc         = yamldecode(local.kubeconfig)
  kc_cluster = local.kc.clusters[0].cluster
  kc_user    = local.kc.users[0].user
  kc_server  = local.kc_cluster.server
  kc_ca_data = base64decode(local.kc_cluster["certificate-authority-data"])
  kc_cert    = base64decode(local.kc_user["client-certificate-data"])
  kc_key     = base64decode(local.kc_user["client-key-data"])

}

provider "kubernetes" {
  host                   = local.kc_server
  cluster_ca_certificate = local.kc_ca_data
  client_certificate     = local.kc_cert
  client_key             = local.kc_key
}


# Flux provider (uses kubeconfig from your Talos module locals)
provider "flux" {

  kubernetes = {
    host                   = local.kc_server
    cluster_ca_certificate = local.kc_ca_data
    client_certificate     = local.kc_cert
    client_key             = local.kc_key
  }

  git = {
    url    = var.flux.repo
    branch = var.flux.branch
    path   = var.flux.path
    http = {
      username = "git"                 # anything works for GH PATs
      password = var.flux.github_token # your PAT here
    }
  }
}

# Bootstrap Flux (idempotent)
resource "flux_bootstrap_git" "this" {
  for_each         = local.flux_enabled ? { cfg = var.flux } : {}
  path             = each.value["path"]
  interval         = "1m"
  components_extra = each.value["extra_components"]
  depends_on       = [talos_machine_bootstrap.this]
}



resource "kubernetes_secret" "sops_secret" {
  for_each = local.sops_by_name
  metadata {
    name      = each.value.name
    namespace = try(each.value["namespace"], null) != null ? each.value["namespace"] : "flux-system"
  }
  type       = "Opaque"
  data       = { "age.agekey" = each.value.key }
  depends_on = [flux_bootstrap_git.this]
}


resource "kubernetes_secret" "pull_secrets" {
  # Create a secret only for registries that have some form of auth info
  for_each = {
    for host, cfg in try(var.registries.config, {}) : host => cfg
    if(try(cfg.auth.username, null) != null && try(cfg.auth.password, null) != null)
    || try(cfg.auth.auth, null) != null
    || try(cfg.auth.identityToken, null) != null
  }

  metadata {
    name      = "pull-secret-${replace(each.key, ".", "-")}"
    namespace = "flux-system"
  }

  depends_on = [flux_bootstrap_git.this]
  type       = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        # The registry host is the key in the docker config
        (each.key) = merge(
          {},

          # username/password (optional)
          try(each.value.auth.username, null) != null ? {
            username = each.value.auth.username
          } : {},
          try(each.value.auth.password, null) != null ? {
            password = each.value.auth.password
          } : {},

          # precomputed auth (base64 of "user:pass"), if provided
          try(each.value.auth.auth, null) != null ? {
            auth = each.value.auth.auth
          } : {},

          # identity token (note the lowercase key name per Docker spec)
          try(each.value.auth.identityToken, null) != null ? {
            identitytoken = each.value.auth.identityToken
          } : {}
        )
      }
    })
  }
}
