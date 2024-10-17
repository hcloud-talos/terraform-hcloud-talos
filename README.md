<div align="center">
  <br>
  <img src="https://github.com/hcloud-talos/terraform-hcloud-talos/blob/main/.idea/icon.png?raw=true" alt="Terraform - Hcloud - Talos" width="200"/>
  <h1 style="margin-top: 0; padding-top: 0;">Terraform - Hcloud - Talos</h1>
  <img alt="GitHub Release" src="https://img.shields.io/github/v/release/hcloud-talos/terraform-hcloud-talos?logo=github">
</div>

---

This repository contains a Terraform module for creating a Kubernetes cluster with Talos in the Hetzner Cloud.

- Talos is a modern OS for Kubernetes. It is designed to be secure, immutable, and minimal.
- Hetzner Cloud is a cloud hosting provider with nice terraform support and cheap prices.

> [!WARNING]  
> This module is under active development. Not all features are compatible with each other yet.
> Known issues are listed in the [Known Issues](#known-issues) section.
> If you find a bug or have a feature request, please open an issue.

---

## Goals 🚀

| Goals                                                                               | Status | Description                                                                                                                                                                                         |
|-------------------------------------------------------------------------------------|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Production ready                                                                    | ✅      | All recommendations from the [Talos Production Clusters](https://www.talos.dev/v1.6/introduction/prodnotes/) are implemented. **But you need to read it carefully to understand all implications.** |
| Use private networks for the internal communication of the cluster                  | ✅      |                                                                                                                                                                                                     |
| Do not expose the Kubernetes and Talos API to the public internet via Load-Balancer | ✅      | Actually, the APIs are exposed to the public internet, but secured via the `firewall_use_current_ip` flag and a firewall rule that only allows traffic from one IP address.                         |
| Possibility to change alls CIDRs of the networks                                    | ⁉️     | Needs to be tested.                                                                                                                                                                                 |
| Configure the Cluster as good as possible to run in the Hetzner Cloud               | ✅      | This includes manual configuration of the network devices and not via DHCP, provisioning of Floating IPs (VIP), etc.                                                                                |

## Information about the Module

- A lot of information can be found directly in the descriptions of the variables.
- You can configure the module to create a cluster with 1, 3 or 5 control planes and n workers or only the control
  planes.
- It allows scheduling pods on the control planes if no workers are created.
- It has [Multihoming](https://www.talos.dev/v1.6/introduction/prodnotes/#multihoming) configuration (etcd and kubelet
  listen on public and private IP).
- It uses [KubePrism](https://www.talos.dev/v1.6/kubernetes-guides/configuration/kubeprism/)
  as [cluster endpoint](https://www.talos.dev/v1.6/reference/cli/#synopsis-9).
- If `cluster_api_host` is set, then you should create a corresponding DNS record pointing to either one control plane, the load balancer,
  floating IP, or alias IP.
  If `cluster_api_host` is not set, then a record for `kube.[cluster_domain]` should be created.
  It totally depends on your setup.

## Additional installed software in the cluster

### [Cilium](https://cilium.io/)

- Cilium is a modern, efficient, and secure networking and security solution for Kubernetes.
- [Cilium is used as the CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/) instead of the default Flannel.
- It provides a lot of features like Network Policies, Load Balancing, and more.

> [!IMPORTANT]  
> The Cilium version (`cilium_version`) has to be compatible with the Kubernetes (`kubernetes_version`) version.

### [Hcloud Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager)

- Updates the `Node` objects with information about the server from the Cloud , like instance Type, Location,
  Datacenter, Server ID, IPs.
- Cleans up stale `Node` objects when the server is deleted in the API.
- Routes traffic to the pods through Hetzner Cloud Networks. Removes one layer of indirection.
- Watches Services with `type: LoadBalancer` and creates Hetzner Cloud Load Balancers for them, adds Kubernetes
  Nodes as targets for the Load Balancer.

### [Talos Cloud Controller Manager](https://github.com/siderolabs/talos-cloud-controller-manager)

- [Applies labels to the nodes](https://github.com/siderolabs/talos-cloud-controller-manager?tab=readme-ov-file#node-initialize).
- [Validates and approves node CSRs](https://github.com/siderolabs/talos-cloud-controller-manager?tab=readme-ov-file#node-certificate-approval).
- In DaemonSet mode: CCM will use hostNetwork and current node to access kubernetes/talos API

## Prerequisites

### Required Software

- [terraform](https://www.terraform.io/downloads.html)
- [packer](https://www.packer.io/downloads)

### Recommended Software

- [hcloud cli](https://github.com/hetznercloud/cli)
- [talosctl](https://www.talos.dev/v1.6/introduction/getting-started/#talosctl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Hetzner Cloud

> [!TIP]
> If you don't have a Hetzner account yet, you are welcome to use
> this [Hetzner Cloud Referral Link](https://hetzner.cloud/?ref=6Q6Q6Q6Q6Q6Q) to claim 20€ credit and support
> this project.

- Create a new project in the Hetzner Cloud Console
- Create a new API token in the project
- You can store the token in the environment variable `HCLOUD_TOKEN` or use it in the following commands/terraform
  files.

## Usage

### Packer

Create the talos os images (ARM and x86) via packer through running the [create.sh](_packer/create.sh).
It is using the `HCLOUD_TOKEN` environment variable to authenticate against the Hetzner Cloud API and uses the project
of the token to store the images.
The talos os version is defined in the variable `talos_version`
in [talos-hcloud.pkr.hcl](_packer/talos-hcloud.pkr.hcl).

```bash
./_packer/create.sh
```

### Terraform

Use the module as shown in the following working minimal example:

> [!NOTE]
> Actually, your current IP address has to have access to the nodes during the creation of the cluster.

```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "the-latest-version-of-the-module"

  talos_version = "v1.8.1" # The version of talos features to use in generated machine configurations

  hcloud_token = "your-hcloud-token"
  
  # If true, the current IP address will be used as the source for the firewall rules.
  # ATTENTION: to determine the current IP, a request to a public service (https://ipv4.icanhazip.com) is made.
  # If false, you have to provide your public IP address (as list) in the variable `firewall_kube_api_source` and `firewall_talos_api_source`.
  firewall_use_current_ip = true

  cluster_name    = "dummy.com"
  datacenter_name = "fsn1-dc14"

  control_plane_count       = 1
  control_plane_server_type = "cax11"
}
```

Or a more advanced example:

```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "the-latest-version-of-the-module"

  talos_version = "v1.8.1"
  kubernetes_version = "1.29.7"
  cilium_version = "1.15.7"

  hcloud_token = "your-hcloud-token"

  cluster_name     = "dummy.com"
  cluster_domain   = "cluster.dummy.com.local"
  cluster_api_host = "kube.dummy.com"

  firewall_use_current_ip = false
  firewall_kube_api_source = ["your-ip"]
  firewall_talos_api_source = ["your-ip"]

  datacenter_name = "fsn1-dc14"

  control_plane_count       = 3
  control_plane_server_type = "cax11"

  worker_count       = 3
  worker_server_type = "cax21"

  network_ipv4_cidr = "10.0.0.0/16"
  node_ipv4_cidr    = "10.0.1.0/24"
  pod_ipv4_cidr     = "10.0.16.0/20"
  service_ipv4_cidr = "10.0.8.0/21"
}
```

You need to pipe the outputs of the module:

```hcl
output "talosconfig" {
  value     = module.talos.talosconfig
  sensitive = true
}

output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}
```

Then you can then run the following commands to export the kubeconfig and talosconfig:

```bash
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig
```

Move these files to the correct location and use them with `kubectl` and `talosctl`.

## Additional Configuration Examples

### Kubelet Extra Args

```hcl
kubelet_extra_args = {
  system-reserved            = "cpu=100m,memory=250Mi,ephemeral-storage=1Gi"
  kube-reserved              = "cpu=100m,memory=200Mi,ephemeral-storage=1Gi"
  eviction-hard              = "memory.available<100Mi,nodefs.available<10%"
  eviction-soft              = "memory.available<200Mi,nodefs.available<15%"
  eviction-soft-grace-period = "memory.available=2m30s,nodefs.available=4m"
}
```

### Sysctls Extra Args

```hcl
sysctls_extra_args = {
  # Fix for https://github.com/cloudflare/cloudflared/issues/1176
  "net.core.rmem_default" = "26214400"
  "net.core.wmem_default" = "26214400"
  "net.core.rmem_max"     = "26214400"
  "net.core.wmem_max"     = "26214400"
}
```

### Activate Kernel Modules

```hcl
kernel_modules_to_load = [
  {
    name = "binfmt_misc" # Required for QEMU
  }
]
```

## Known Limitations

- Changes in the `user_data` (e.g. `talos_machine_configuration`) and `image` (e.g. version upgrades with `packer`) will
  not be applied to existing nodes, because it would force a recreation of the nodes.

## Known Issues

- IPv6 dual stack is not supported by Talos yet. You can activate IPv6 with `enable_ipv6`, but it should not have any
  effect.
- `enable_kube_span` let's the cluster not get in ready state. It is not clear why yet. I have to investigate it.
- `403 Forbidden user` in startup log: This is a known issue with Hetzner IPs.
  See [#46](https://github.com/hcloud-talos/terraform-hcloud-talos/issues/46) and [registry.k8s.io #138](https://github.com/kubernetes/registry.k8s.io/issues/138)

## Credits

- [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) For the inspiration and the great
  terraform module. This module is based on many ideas and code snippets from kube-hetzner.
- [Talos](https://www.talos.dev/) For the incredible OS.
- [Hetzner Cloud](https://www.hetzner.com/cloud) For the great cloud hosting.
