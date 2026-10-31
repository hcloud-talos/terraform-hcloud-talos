locals {
  # Talos 1.14 generates separate documents for these settings. Do not also
  # set their legacy fields: Talos rejects configurations with both formats.
  node_yaml = merge(local.controlplane_yaml, local.worker_yaml)
  talos_1_14_node_patches = {
    for name, config in local.node_yaml : name => [
      yamlencode({
        machine = {
          for key, value in config.machine : key => value
          if !contains(["install", "kubelet", "nodeLabels", "features"], key)
        }
        cluster = {
          for key, value in config.cluster : key => value if key == "etcd"
        }
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UnattendedInstallConfig"
        installer  = { image = config.machine.install.image }
        provisioning = {
          diskSelector = { match = "disk.dev_path == \"/dev/sda\"" }
        }
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        auto       = "off"
        hostname   = name
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "ResolverConfig"
        hostDNS    = config.machine.features.hostDNS
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeletConfig"
        extraArgs  = config.machine.kubelet.extraArgs
        config     = try(config.machine.kubelet.extraConfig, {})
      }),
      yamlencode(merge({
        apiVersion = "v1alpha1"
        kind       = "KubeNodeConfig"
        nodeIP     = config.machine.kubelet.nodeIP
        labels     = config.machine.nodeLabels
        }, try(config.cluster.allowSchedulingOnControlPlanes, false) ? {
        taints = {
          "node-role.kubernetes.io/control-plane" = { "$patch" = "delete" }
        }
      } : {})),
      yamlencode({
        apiVersion     = "v1alpha1"
        kind           = "KubeNetworkConfig"
        dnsDomain      = config.cluster.network.dnsDomain
        podSubnets     = config.cluster.network.podSubnets
        serviceSubnets = config.cluster.network.serviceSubnets
      }),
    ]
  }

  talos_1_14_control_plane_patches = {
    for name, config in local.controlplane_yaml : name => concat([
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeFlannelCNIConfig"
        "$patch"   = "delete"
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeCoreDNSConfig"
        enabled    = !config.cluster.coreDNS.disabled
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeProxyConfig"
        enabled    = false
      }),
      yamlencode({
        apiVersion    = "v1alpha1"
        kind          = "KubeAPIServerConfig"
        certExtraSANs = config.cluster.apiServer.certSANs
        extraArgs     = config.cluster.apiServer.extraArgs
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeControllerManagerConfig"
        extraArgs  = config.cluster.controllerManager.extraArgs
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeSchedulerConfig"
        extraArgs  = config.cluster.scheduler.extraArgs
      }),
      yamlencode({
        apiVersion                  = "v1alpha1"
        kind                        = "KubeTalosAPIAccessConfig"
        allowedRoles                = config.machine.features.kubernetesTalosAPIAccess.allowedRoles
        allowedKubernetesNamespaces = config.machine.features.kubernetesTalosAPIAccess.allowedKubernetesNamespaces
      }),
      ], [
      for manifest in config.cluster.inlineManifests : yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeInlineManifestConfig"
        name       = manifest.name
        manifest   = manifest.contents
      })
      ], [
      for index, url in concat(coalesce(config.cluster.extraManifests, []), config.cluster.externalCloudProvider.manifests) : yamlencode({
        apiVersion = "v1alpha1"
        kind       = "KubeExternalManifestConfig"
        name       = "extra-${index}"
        url        = url
      })
    ])
  }

  machine_config_patches = {
    for name, config in local.node_yaml : name => startswith(var.talos_version, "v1.14.") ? concat(
      local.talos_1_14_node_patches[name],
      lookup(local.talos_1_14_control_plane_patches, name, []),
    ) : [yamlencode(config)]
  }
}
