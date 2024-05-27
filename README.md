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
> It's under active development. Not all features are compatible with each other yet.
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

- You can configure the module to create a cluster with 1, 3 or 5 control planes and n workers or only the control
  planes.
- It allows scheduling pods on the control planes if no workers are created.
- It has [Multihoming](https://www.talos.dev/v1.6/introduction/prodnotes/#multihoming) configuration (etcd and kubelet
  listen on public and private IP).
- It uses [KubePrism](https://www.talos.dev/v1.6/kubernetes-guides/configuration/kubeprism/)
  as [cluster endpoint](https://www.talos.dev/v1.6/reference/cli/#synopsis-9).
- It prepares for the kube-prometheus-stack by enabling listening and enabling service monitors in cilium.
- If `cluster_api_host` is set, you should create a DNS record, pointing to the Control Plane node private IPs.

## Additional installed software in the cluster

### [Cilium](https://cilium.io/)

- Cilium is a modern, efficient, and secure networking and security solution for Kubernetes.
- It is used [Cilium as the CNI instead of the
  default Flannel](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/) instead of the
  default Flannel.
- It provides a lot of features like Network Policies, Load Balancing, and more.

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

Create the talos os images (AMD and x86) via packer through running the [create.sh](_packer/create.sh).
It is using the `HCLOUD_TOKEN` environment variable to authenticate against the Hetzner Cloud API and uses the project
of the token to store the images.
The talos os version is defined in the variable `talos_version`
in [talos-hcloud.pkr.hcl](_packer/talos-hcloud.pkr.hcl).

```bash
./_packer/create.sh
```

### Terraform

Use the module as shown in the following working example:

> [!NOTE]
> Actually, your current IP address has to have access to the nodes during the creation of the cluster.

```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "1.8.2"

  hcloud_token = "your-hcloud-token"

  cluster_name     = "dummy.com"
  cluster_domain   = "cluster.dummy.com.local"
  cluster_api_host = "kube.dummy.com"

  firewall_use_current_ip = true

  datacenter_name = "fsn1-dc14"

  control_plane_count       = 3
  control_plane_server_type = "cax11"

  worker_count       = 3
  worker_server_type = "cax21"
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

## Known Limitations

- Changes in the `user_data` (e.g. `talos_machine_configuration`) and `image` (e.g. version upgrades with `packer`) will
  not be applied to existing nodes, because it would force a recreation of the nodes.

## Known Issues

- IPv6 dual stack is not supported by Talos yet. You can activate IPv6 with `enable_ipv6`, but it should not have any
  effect.

## Future Plans

- [ ] Add Alias IP support (Required PR to get merged: https://github.com/siderolabs/talos/pull/8493)
- [ ] Add Hetzner Cloud CSI Driver

## Credits

- [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) For the inspiration and the great
  terraform module. This module is based on many ideas and code snippets from kube-hetzner.
- [Talos](https://www.talos.dev/) For the incredible OS.
- [Hetzner Cloud](https://www.hetzner.com/cloud) For the great cloud hosting.
