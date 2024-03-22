locals {
  worker_yaml = [
    for index in range(0, var.control_plane_count) : yamlencode({
      machine = {
        install = {
          extraKernelArgs = [
            "ipv6.disable=${var.enable_ipv6 ? 0 : 1}",
          ]
        }
        kubelet = {
          extraArgs = {
            "cloud-provider"             = "external"
            "rotate-server-certificates" = true
          }
          clusterDNS = concat(
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
              interface = "eth0"
              dhcp      = false
              addresses : [
                local.worker_public_ipv4_list[index],
                var.enable_ipv6 ? local.worker_public_ipv6_list[index] : null
              ]
              routes = concat([
                {
                  network = "172.31.1.1/32"
                },
                {
                  network = "0.0.0.0/0"
                  gateway : "172.31.1.1"
                }
                ],
                var.enable_ipv6 ? [
                  {
                    network = local.worker_public_ipv6_subnet_list[index]
                    gateway : "fe80::1"
                  }
                ] : []
              )
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
          dnsDomain = var.cluster_domain
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
  ]
}