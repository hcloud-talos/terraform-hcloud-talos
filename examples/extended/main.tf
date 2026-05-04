terraform {
  required_version = ">=1.10.0"

  required_providers {
    onepassword = {
      source  = "1password/onepassword"
      version = ">= 3.3.1"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.60.1"
    }

    imager = {
      source  = "hcloud-talos/imager"
      version = ">= 1.0.6"
    }

    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.7.0"
    }
  }
}

provider "onepassword" {
  // OnePassword Service Account Token
  service_account_token = var.op_service_account_token_test
}

locals {
  hcloud_token = one(flatten([
    for s in data.onepassword_item.hetzner_token.section : [
      for f in s.field : f.value if f.label == "token"
    ]
  ]))

  talos_version = "v1.12.2"
}

provider "hcloud" {
  token = local.hcloud_token
}

provider "imager" {
  token = local.hcloud_token
}

provider "talos" {}

resource "talos_image_factory_schematic" "x86" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = []
      }
    }
  })
}

data "talos_image_factory_urls" "hcloud_amd64" {
  talos_version = local.talos_version
  schematic_id  = talos_image_factory_schematic.x86.id
  platform      = "hcloud"
  architecture  = "amd64"
}

resource "imager_image" "talos_x86" {
  image_url    = data.talos_image_factory_urls.hcloud_amd64.urls.disk_image
  architecture = "x86"
  description  = "Talos Linux ${local.talos_version} x86 example-extended"

  labels = {
    version = local.talos_version
  }
}

module "talos" {
  # Local module source (repo root) for testing migrations / current version.
  source = "../.."

  hcloud_token = local.hcloud_token

  talos_version      = local.talos_version
  kubernetes_version = "1.35.0"
  talos_image_id_x86 = imager_image.talos_x86.id

  disable_arm = true

  firewall_use_current_ip = true

  enable_alias_ip            = true
  enable_floating_ip         = true
  kubeconfig_endpoint_mode   = "public_ip"
  talosconfig_endpoints_mode = "public_ip"

  cluster_name = "example-extended"

  location_name = "fsn1"

  control_plane_nodes = [
    { id = 1, type = "cx33" },
    { id = 2, type = "cx33" },
    { id = 3, type = "cx33" },
  ]

  worker_nodes = [
    {
      id   = 1
      type = "cx43"
    },
    {
      id   = 2
      type = "cx43"
    },
  ]

  kube_api_extra_args = {
    # Because of https://github.com/kubernetes-sigs/metrics-server/blob/master/README.md#high-availability
    enable-aggregator-routing = true
  }

  sysctls_extra_args = {
    # Fix for https://github.com/cloudflare/cloudflared/issues/1176
    "net.core.rmem_default" = "26214400"
    "net.core.wmem_default" = "26214400"
    "net.core.rmem_max"     = "26214400"
    "net.core.wmem_max"     = "26214400"
  }

  kernel_modules_to_load = [
    { name = "binfmt_misc" } # Required for QEMU in gha-runner-system runners
  ]

  talos_control_plane_extra_config_patches = [
    file("patches/kubelet/control-plane.yaml"), # Additional kubelet args for control plane nodes
    file("patches/registries.yaml")             # Containerd registry mirrors for pull-through cache
  ]
  talos_worker_extra_config_patches = [
    file("patches/kubelet/worker.yaml"), # Additional kubelet args for worker nodes
    file("patches/registries.yaml")      # Containerd registry mirrors for pull-through cache
  ]

  # Cilium bootstrap values - GitOps manages post-bootstrap (ArgoCD in my case)
  deploy_cilium  = true # set to false after first deployment and let GitOps handle upgrades
  cilium_version = "1.18.5"
  # cilium_values  = [templatefile("../path/to/your/git-ops/cilium/values.yaml", {})]

  deploy_prometheus_operator_crds  = true # set to false after first deployment and let GitOps handle upgrades
  prometheus_operator_crds_version = "26.0.0"

  deploy_hcloud_ccm = true # set to false after first deployment and let GitOps handle upgrades

  disable_talos_coredns = false # set to true after first deployment and let GitOps handle upgrades
}
