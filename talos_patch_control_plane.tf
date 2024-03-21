locals {
  controlplane_yaml = [
    for index in range(0, var.control_plane_count) : yamlencode({
      machine = {
        install = {
          extraKernelArgs = [
            "ipv6.disable=${var.enable_ipv6 ? 0 : 1}",
          ]
        }
        certSANs = local.cert_SANs
        kubelet = {
          extraArgs = {
            "cloud-provider"             = "external"
            "rotate-server-certificates" = "true"
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
              addresses : compact([
                local.control_plane_public_ipv4_list[index],
                var.enable_ipv6 ? local.control_plane_public_ipv6_list[index] : null
              ])
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
                    network = local.control_plane_public_ipv6_subnet_list[index]
                    gateway : "fe80::1"
                  }
                ] : []
              )
              vip = var.enable_floating_ip ? {
                ip = hcloud_floating_ip.control_plane_ipv4[0].ip_address
                hcloud = {
                  apiToken = var.hcloud_token
                }
              } : null
            },
          ]
          extraHostEntries = local.extra_host_entries
        }
        sysctls = {
          "net.core.somaxconn"          = "65535"
          "net.core.netdev_max_backlog" = "4096"
        }
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
        allowSchedulingOnControlPlanes = var.worker_count <= 0
        network = {
          dnsDomain = local.cluster_domain
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
        proxy = {
          disabled = true
        }
        apiServer = {
          certSANs = local.cert_SANs
        }
        controllerManager = {
          extraArgs = {
            "cloud-provider"           = "external"
            "node-cidr-mask-size-ipv4" = local.node_ipv4_cidr_mask_size
          }
        }
        etcd = {
          advertisedSubnets = [
            local.node_ipv4_cidr
          ]
          extraArgs = {
            "listen-metrics-urls" = "http://0.0.0.0:2381"
          }
        }
        inlineManifests = [
          {
            name = "hcloud-secret"
            contents = replace(yamlencode({
              apiVersion = "v1"
              kind       = "Secret"
              type       = "Opaque"
              metadata = {
                name      = "hcloud"
                namespace = "kube-system"
              }
              data = {
                network = base64encode(hcloud_network.this.id)
                token   = base64encode(var.hcloud_token)
              }
            }), "\"", "")
          }
        ]
        externalCloudProvider = {
          enabled = true
          manifests = [
            "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/v1.4.0/docs/deploy/cloud-controller-manager-daemonset.yml"
          ]
        }
      }
    })
  ]
}