locals {
  worker_yaml = {
    for worker in local.workers : worker.name => {
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
                worker.ipv4,
                worker.ipv6
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
                    network = worker.ipv6_subnet
                    gateway : "fe80::1"
                  }
                ] : []
              )
            }
          ]
          extraHostEntries = local.extra_host_entries
          kubespan = {
            enabled = var.enable_kube_span
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
          kubernetesTalosAPIAccess = {
            enabled = true
            allowedRoles = [
              "os:reader"
            ]
            allowedKubernetesNamespaces = [
              "kube-system"
            ]
          }
          hostDNS = {
            enabled              = true
            forwardKubeDNSToHost = true
            resolveMemberNames   = true
          }
        },
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
}
