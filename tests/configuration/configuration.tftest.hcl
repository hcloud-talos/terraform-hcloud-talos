variables {
  hcloud_token       = "test-token"
  cluster_name       = "test"
  talos_version      = "v1.14.3"
  kubernetes_version = "1.35.0"
  control_plane_nodes = [{
    id   = 1
    type = "cx23"
  }]
}

run "talos_1_14_without_workers" {
  command = apply

  assert {
    condition = !contains(
      keys(output.control_planes["control-plane-1"].KubeNodeConfig[0].labels),
      "node.kubernetes.io/exclude-from-external-load-balancers"
    )
    error_message = "A cluster without workers must not exclude control planes from load balancers."
  }

  assert {
    condition = !contains(
      keys(try(output.control_planes["control-plane-1"].KubeNodeConfig[0].taints, {})),
      "node-role.kubernetes.io/control-plane"
    )
    error_message = "A cluster without workers must allow scheduling on its control planes."
  }

  assert {
    condition = (
      !contains(keys(output.control_planes["control-plane-1"]), "KubeFlannelCNIConfig") &&
      output.control_planes["control-plane-1"].KubeProxyConfig[0].enabled == false &&
      output.control_planes["control-plane-1"].KubeCoreDNSConfig[0].enabled == true &&
      output.control_planes["control-plane-1"].ResolverConfig[0].hostDNS.resolveMemberNames == true &&
      output.control_planes["control-plane-1"].HostnameConfig[0].hostname == "control-plane-1" &&
      output.control_planes["control-plane-1"].UnattendedInstallConfig[0].installer.image == "ghcr.io/siderolabs/installer:v1.14.3" &&
      output.control_planes["control-plane-1"].UnattendedInstallConfig[0].provisioning.diskSelector.match == "disk.dev_path == \"/dev/sda\"" &&
      output.control_planes["control-plane-1"].KubeNetworkConfig[0].podSubnets == ["10.0.16.0/20"] &&
      output.control_planes["control-plane-1"].KubeNodeConfig[0].nodeIP.validSubnets == ["10.0.1.0/24"] &&
      output.control_planes["control-plane-1"].legacy[0].machine.network.interfaces[1].vip.ip == "10.0.1.100"
    )
    error_message = "Talos 1.14 must preserve CNI, DNS, hostname, installer, network, and VIP settings."
  }

  assert {
    condition = (
      output.control_planes["control-plane-1"].KubeTalosAPIAccessConfig[0].allowedRoles[0] == "os:reader" &&
      output.control_planes["control-plane-1"].KubeInlineManifestConfig[0].name == "hcloud-secret" &&
      endswith(output.control_planes["control-plane-1"].KubeExternalManifestConfig[0].url, "/cloud-controller-manager-daemonset.yml")
    )
    error_message = "Talos 1.14 must preserve the cloud controller manifests and Talos access settings."
  }
}

run "talos_1_13_without_workers" {
  command = apply
  variables {
    talos_version = "v1.13.11"
  }

  assert {
    condition = (
      !contains(keys(try(output.control_planes["control-plane-1"].legacy[0].machine.nodeLabels, {})), "node.kubernetes.io/exclude-from-external-load-balancers") &&
      output.control_planes["control-plane-1"].legacy[0].cluster.allowSchedulingOnControlPlanes &&
      output.control_planes["control-plane-1"].legacy[0].cluster.network.cni.name == "none" &&
      output.control_planes["control-plane-1"].legacy[0].cluster.proxy.disabled &&
      output.control_planes["control-plane-1"].legacy[0].machine.install.image == "ghcr.io/siderolabs/installer:v1.13.11"
    )
    error_message = "Talos 1.13 must retain the legacy configuration format and allow clusters without workers."
  }
}

run "talos_1_14_with_workers" {
  command = apply
  variables {
    control_plane_nodes = [{
      id     = 1
      type   = "cx23"
      labels = { workload = "control" }
      taints = [{ key = "dedicated", value = "control", effect = "NoSchedule" }]
    }]
    worker_nodes = [{
      id     = 1
      type   = "cx23"
      labels = { workload = "worker" }
      taints = [{ key = "dedicated", value = "worker", effect = "PreferNoSchedule" }]
    }]
    kubelet_extra_args    = { "max-pods" = "80" }
    kube_api_extra_args   = { "event-ttl" = "2h" }
    sysctls_extra_args    = { "net.core.somaxconn" = "8192" }
    extraManifests        = ["https://example.test/manifest.yaml"]
    enable_floating_ip    = true
    disable_talos_coredns = true
    registries = {
      mirrors = { "docker.io" = { endpoints = ["https://mirror.example.test"] } }
    }
  }

  assert {
    condition = (
      contains(keys(output.control_planes["control-plane-1"].KubeNodeConfig[0].labels), "node.kubernetes.io/exclude-from-external-load-balancers") &&
      output.control_planes["control-plane-1"].KubeNodeConfig[0].taints["node-role.kubernetes.io/control-plane"] == "NoSchedule" &&
      output.control_planes["control-plane-1"].KubeNodeConfig[0].labels.workload == "control" &&
      output.control_planes["control-plane-1"].KubeletConfig[0].config.registerWithTaints[0].value == "control" &&
      output.workers["worker-1"].KubeNodeConfig[0].labels.workload == "worker" &&
      output.workers["worker-1"].KubeletConfig[0].config.registerWithTaints[0].effect == "PreferNoSchedule" &&
      output.workers["worker-1"].HostnameConfig[0].hostname == "worker-1"
    )
    error_message = "Talos 1.14 must preserve control-plane isolation and custom node labels and taints."
  }

  assert {
    condition = (
      output.workers["worker-1"].KubeletConfig[0].extraArgs["max-pods"] == "80" &&
      output.control_planes["control-plane-1"].KubeAPIServerConfig[0].extraArgs["event-ttl"] == "2h" &&
      output.control_planes["control-plane-1"].legacy[0].machine.sysctls["net.core.somaxconn"] == "8192" &&
      output.control_planes["control-plane-1"].legacy[0].machine.network.interfaces[0].vip.ip == "192.0.2.20" &&
      output.control_planes["control-plane-1"].KubeCoreDNSConfig[0].enabled == false &&
      output.workers["worker-1"].legacy[0].machine.registries.mirrors["docker.io"].endpoints[0] == "https://mirror.example.test" &&
      contains([for manifest in output.control_planes["control-plane-1"].KubeExternalManifestConfig : manifest.url], "https://example.test/manifest.yaml")
    )
    error_message = "Talos 1.14 must preserve user settings and extra manifests."
  }
}

run "talos_1_13_with_workers" {
  command = apply
  variables {
    talos_version = "v1.13.11"
    worker_nodes = [{
      id     = 1
      type   = "cx23"
      labels = { workload = "worker" }
      taints = [{ key = "dedicated", value = "worker", effect = "PreferNoSchedule" }]
    }]
  }

  assert {
    condition = (
      contains(keys(output.control_planes["control-plane-1"].legacy[0].machine.nodeLabels), "node.kubernetes.io/exclude-from-external-load-balancers") &&
      !try(output.control_planes["control-plane-1"].legacy[0].cluster.allowSchedulingOnControlPlanes, false) &&
      output.workers["worker-1"].legacy[0].machine.nodeLabels.workload == "worker" &&
      output.workers["worker-1"].legacy[0].machine.kubelet.extraConfig.registerWithTaints[0].value == "worker"
    )
    error_message = "Talos 1.13 must preserve control-plane isolation and worker settings."
  }
}

run "scheduling_and_user_patches" {
  command = apply
  variables {
    worker_nodes                 = [{ id = 1, type = "cx23" }]
    control_plane_allow_schedule = true
    tailscale                    = { enabled = true, auth_key = "test" }
    talos_control_plane_extra_config_patches = [<<-YAML
      apiVersion: v1alpha1
      kind: KubeNodeConfig
      labels:
        custom: control
      YAML
    ]
    talos_worker_extra_config_patches = [<<-YAML
      apiVersion: v1alpha1
      kind: KubeNodeConfig
      labels:
        custom: worker
      YAML
    ]
  }

  assert {
    condition = (
      !contains(keys(try(output.control_planes["control-plane-1"].KubeNodeConfig[0].taints, {})), "node-role.kubernetes.io/control-plane") &&
      contains(keys(output.control_planes["control-plane-1"].KubeNodeConfig[0].labels), "node.kubernetes.io/exclude-from-external-load-balancers") &&
      output.control_planes["control-plane-1"].KubeNodeConfig[0].labels.custom == "control" &&
      output.workers["worker-1"].KubeNodeConfig[0].labels.custom == "worker" &&
      output.control_planes["control-plane-1"].ExtensionServiceConfig[0].name == "tailscale"
    )
    error_message = "Scheduling, user patches, and the Tailscale document must remain available."
  }
}

run "example_patches" {
  command = apply
  variables {
    worker_nodes = [{ id = 1, type = "cx23" }]
    talos_control_plane_extra_config_patches = [
      file("./example-patches/control-plane.yaml"),
      file("./example-patches/registries.yaml"),
    ]
    talos_worker_extra_config_patches = [
      file("./example-patches/worker.yaml"),
      file("./example-patches/registries.yaml"),
    ]
  }

  assert {
    condition = (
      output.control_planes["control-plane-1"].KubeletConfig[0].extraArgs["system-reserved"] == "cpu=300m,memory=640Mi,ephemeral-storage=1Gi" &&
      output.workers["worker-1"].KubeletConfig[0].extraArgs["max-pods"] == "110"
    )
    error_message = "The extended example patches must use the supported Talos configuration format."
  }
}

run "three_control_planes_without_workers" {
  command = apply
  variables {
    control_plane_nodes = [
      { id = 1, type = "cx23", taints = [{ key = "dedicated", value = "control", effect = "PreferNoSchedule" }] },
      { id = 2, type = "cx23" },
      { id = 3, type = "cx23" },
    ]
  }

  assert {
    condition = length(output.control_planes) == 3 && alltrue([
      for config in output.control_planes :
      !contains(keys(config.KubeNodeConfig[0].labels), "node.kubernetes.io/exclude-from-external-load-balancers") &&
      !contains(keys(try(config.KubeNodeConfig[0].taints, {})), "node-role.kubernetes.io/control-plane")
    ])
    error_message = "All three control planes must allow workloads and load balancer traffic."
  }

  assert {
    condition     = output.control_planes["control-plane-1"].KubeletConfig[0].config.registerWithTaints[0].value == "control"
    error_message = "Automatic scheduling must not remove custom taints."
  }
}
