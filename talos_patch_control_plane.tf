locals {
  # Define a dummy control plane entry for when count is 0
  dummy_control_planes = var.control_plane_count == 0 ? [{
    index              = 0
    name               = "dummy-cp-0"
    ipv4_public        = "0.0.0.0"                           # Fallback
    ipv6_public        = null                                # Fallback
    ipv6_public_subnet = null                                # Fallback
    ipv4_private       = cidrhost(local.node_ipv4_cidr, 100) # Use a predictable dummy private IP
  }] : []

  # Combine real and dummy control planes
  merged_control_planes = concat(local.control_planes, local.dummy_control_planes)

  # Generate YAML for all (real or dummy) control planes
  controlplane_yaml = {
    for control_plane in local.merged_control_planes : control_plane.name => {
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
        nodeLabels = var.worker_count <= 0 ? {
          "node.kubernetes.io/exclude-from-external-load-balancers" = {
            "$patch" = "delete"
          }
        } : {}
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
              vip = var.enable_floating_ip ? {
                ip = data.hcloud_floating_ip.control_plane_ipv4[0].ip_address
                hcloud = {
                  apiToken = var.hcloud_token
                }
              } : null
            },
            {
              interface = "eth1"
              dhcp      = true
              vip = var.enable_alias_ip ? {
                ip = local.control_plane_private_vip_ipv4
                hcloud = {
                  apiToken = var.hcloud_token
                }
              } : null
            }
          ]
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
        allowSchedulingOnControlPlanes = var.worker_count <= 0
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
        coreDNS = {
          disabled = var.disable_talos_coredns
        }
        proxy = {
          disabled = true
        }
        apiServer = {
          certSANs  = local.cert_SANs
          extraArgs = var.kube_api_extra_args
        }
        controllerManager = {
          extraArgs = {
            "cloud-provider"           = "external"
            "node-cidr-mask-size-ipv4" = local.node_ipv4_cidr_mask_size
            "bind-address" : "0.0.0.0"
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
        scheduler = {
          extraArgs = {
            "bind-address" = "0.0.0.0"
          }
        }
        extraManifests = var.extraManifests
        inlineManifests = [
          {
            name     = "hcloud-secret"
            contents = <<-EOT
              apiVersion: v1
              kind: Secret
              type: Opaque
              metadata:
                name: hcloud
                namespace: kube-system
              data:
                network: ${base64encode(hcloud_network.this.id)}
                token: ${base64encode(var.hcloud_token)}
            EOT
          }
        ]
        externalCloudProvider = {
          enabled = true
          manifests = [
            "https://raw.githubusercontent.com/siderolabs/talos-cloud-controller-manager/v1.6.0/docs/deploy/cloud-controller-manager-daemonset.yml"
          ]
        }
      }
    }
  }
}
