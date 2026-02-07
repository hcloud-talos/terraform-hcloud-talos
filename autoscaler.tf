variable "autoscaler_nodepools" {
  description = "Cluster autoscaler nodepools."
  type = list(object({
    name          = string
    instance_type = string
    region        = string
    min_nodes     = number
    max_nodes     = number
    labels        = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = []
}


locals {

  cluster_config = {
    imagesForArch = {
      arm64 = var.disable_arm ? null : tostring(data.hcloud_image.arm[0].id)
      amd64 = var.disable_x86 ? null : tostring(data.hcloud_image.x86[0].id)
    }
    nodeConfigs = {
      for index, nodePool in var.autoscaler_nodepools :
      ("${nodePool.name}") => {
        cloudInit = data.talos_machine_configuration.autoscaler.machine_configuration
        labels    = nodePool.labels
        taints    = nodePool.taints
      }
    }
  }

  worker_patches = {
    machine = {
      install = {
        image = "ghcr.io/siderolabs/installer:${var.talos_version}"
        extraKernelArgs = [
          "ipv6.disable=${var.enable_ipv6 ? 0 : 1}",
        ]
      }
      certSANs = local.cert_SANs
      kubelet = {
        extraArgs = merge(
          {
            "cloud-provider"             = "external"
            "rotate-server-certificates" = true
          },
          var.kubelet_extra_args
        )
        nodeIP = {
          validSubnets = [
            local.node_ipv4_cidr
          ]
        }
      }
      network = {
        extraHostEntries = local.extra_host_entries
        kubespan = {
          enabled = var.enable_kube_span
          advertiseKubernetesNetworks : false # Disabled because of cilium
          mtu : 1370                          # Hcloud has a MTU of 1450 (KubeSpanMTU = UnderlyingMTU - 80)
        }
      }
      kernel = {
        modules = var.kernel_modules_to_load
      }
      sysctls = merge(
        {
          "net.core.somaxconn"          = "65535"
          "net.core.netdev_max_backlog" = "4096"
        },
        var.sysctls_extra_args
      )
      features = {
        hostDNS = {
          enabled              = true
          forwardKubeDNSToHost = true
          resolveMemberNames   = true
        }
      }
      time = {
        servers = [
          "ntp1.hetzner.de",
          "ntp2.hetzner.com",
          "ntp3.hetzner.net",
          "time.cloudflare.com"
        ]
      }
      registries = var.registries
    }
    cluster = {
      network = {
        dnsDomain = var.cluster_domain
        podSubnets = [
          local.pod_ipv4_cidr
        ]
        serviceSubnets = [
          local.service_ipv4_cidr
        ]
        cni = {
          name = "none"
        }
      }
    }
  }
}

data "talos_machine_configuration" "autoscaler" {
  talos_version      = var.talos_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint_url_internal
  kubernetes_version = var.kubernetes_version
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = concat([yamlencode(local.worker_patches)], var.talos_worker_extra_config_patches)
  docs               = false
  examples           = false
}

resource "kubernetes_secret" "hetzner_api_token" {
  metadata {
    name      = "hetzner-api-token"
    namespace = "kube-system"
  }

  data = {
    token = var.hcloud_token
  }
}

resource "helm_release" "autoscaler" {
  name = "autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.46.6"

  values = [yamlencode({
    cloudProvider = "hetzner"
    autoDiscovery = {
      clusterName = var.cluster_name
    }

    extraEnvSecrets = {
      HCLOUD_TOKEN = {
        name = "hetzner-api-token"
        key = "token"
      }
    }

    extraEnv = {
      HCLOUD_FIREWALL       = tostring(hcloud_firewall.this.id)
      HCLOUD_NETWORK        = tostring(hcloud_network_subnet.nodes.network_id)
      HCLOUD_CLUSTER_CONFIG = base64encode(jsonencode(local.cluster_config))
    }

    autoscalingGroups = [
      for np in var.autoscaler_nodepools : {
        name         = np.name
        maxSize      = np.max_nodes
        minSize      = np.min_nodes
        instanceType = np.instance_type
        region       = np.region
      }
    ]
  })]
}


