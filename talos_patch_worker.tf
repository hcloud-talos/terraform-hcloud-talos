locals {
  worker_yaml = yamlencode({
    machine = {
      kubelet = {
        extraArgs = {
          "cloud-provider"             = "external"
          "rotate-server-certificates" = true
        }
        clusterDNS = concat(
          ["169.254.2.53"],
          [cidrhost(local.service_ipv4_cidr, 10)]
        )
        nodeIP = {
          validSubnets = [
            local.node_ipv4_cidr
          ]
        }
      }
      network = {
        interfaces = [
          {
            interface = "dummy0"
            addresses = [
              "169.254.2.53/32"
            ]
          }
        ]
        extraHostEntries = local.extra_host_entries
      }
      sysctls = {
        "net.core.somaxconn"          = "65535"
        "net.core.netdev_max_backlog" = "4096"
      }
      time = {
        servers = [
          "ntp1.hetzner.de",
          "ntp2.hetzner.com",
          "ntp3.hetzner.net",
          "time.cloudflare.com"
        ]
      }
    }
    cluster = {
      network = {
        dnsDomain = local.cluster_domain
        podSubnets = [
          local.pod_ipv4_cidr
        ]
        serviceSubnets = [
          local.service_ipv4_cidr
        ]
      }
      proxy = {
        disabled = true
      }
    }
  })
}