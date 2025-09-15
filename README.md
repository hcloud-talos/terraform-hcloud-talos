<div align="center">
  <br>
  <img src="https://github.com/hcloud-talos/terraform-hcloud-talos/blob/main/.idea/icon.png?raw=true" alt="Terraform - Hcloud - Talos" width="200"/>
  <h1 style="margin-top: 0; padding-top: 0;">Terraform - Hcloud - Talos</h1>
  <img alt="GitHub Release" src="https://img.shields.io/github/v/release/hcloud-talos/terraform-hcloud-talos?logo=github">
</div>

---

This repository contains a Terraform module for creating a Kubernetes cluster with Talos in the Hetzner Cloud.

- Talos is a modern OS for Kubernetes. It is designed to be secure, immutable, and minimal.
- Hetzner Cloud is a cloud hosting provider with excellent Terraform support and competitive pricing.

> [!WARNING]
> This module is under active development. Not all features are compatible with each other yet.
> Known issues are listed in the [Known Issues](#known-issues) section.
> If you find a bug or have a feature request, please open an issue.

---

## Goals 🚀

| Goals                                                              | Status | Description                                                                                                                                                                                           |
|--------------------------------------------------------------------|--------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Production ready                                                   | ✅      | All recommendations from the [Talos Production Clusters](https://www.talos.dev/v1.6/introduction/prodnotes/) are implemented. **But you need to read it carefully to understand all implications.**   |
| Use private networks for the internal communication of the cluster | ✅      | Hetzner Cloud Networks are used for internal node-to-node communication.                                                                                                                              |
| Secure API Exposure                                                | ✅      | The Kubernetes and Talos APIs are exposed to the public internet but secured via firewall rules. By default (`firewall_use_current_ip = true`), only traffic from your current IP address is allowed. |
| Possibility to change all CIDRs of the networks                    | ✅      | All network CIDRs (network, node, pod, service) can be customized.                                                                                                                                    |
| Configure the Cluster optimally to run in the Hetzner Cloud        | ✅      | This includes manual configuration of the network devices and not via DHCP, provisioning of Floating IPs (VIP), etc.                                                                                  |

## Information about the Module

- A lot of information can be found directly in the descriptions of the variables.
- You can configure the module to create a cluster with 1, 3 or 5 control planes and n workers or only the control
  planes.
- It allows scheduling pods on the control planes if no workers are created.
- It has [Multihoming](https://www.talos.dev/v1.6/introduction/prodnotes/#multihoming) configuration (etcd and kubelet
  listen on public and private IP).
- It uses [KubePrism](https://www.talos.dev/v1.6/kubernetes-guides/configuration/kubeprism/)
  for internal API server access (`127.0.0.1:7445`) from within the cluster nodes.
- **Public API Endpoint:**
  - You can define a stable public endpoint for your cluster using the `cluster_api_host` variable (
    e.g., `kube.mydomain.com`).
  - If you set `cluster_api_host`, you **must** create a DNS A record for this hostname pointing to the public IP
    address you want clients to use. This could be:
    - The Hetzner Floating IP (if `enable_floating_ip = true`).
    - The IP of an external Load Balancer you configure separately.
    - The public IP of a specific control plane node (less recommended for multi-node control planes).
  - The generated `kubeconfig` and `talosconfig` will use this hostname
    if `output_mode_config_cluster_endpoint = "cluster_endpoint"`.
  - **Note:** When using `talosctl` from outside the cluster, ensure you use the publicly resolvable endpoint (e.g.,
    `cluster_api_host` or the Floating IP) with the `--endpoint` flag, as internal hostnames like
    `kube.[cluster_domain]` are not externally resolvable.
- **Internal API Endpoint:**
  - For internal communication _between cluster nodes_, Talos often uses the hostname `kube.[cluster_domain]` (
    e.g., `kube.cluster.local`).
  - If `enable_alias_ip = true` (the default), this module automatically configures `/etc/hosts` entries on each node
    to resolve `kube.[cluster_domain]` to the _private_ alias IP (`10.0.1.100` by default). This ensures reliable
    internal communication.
- **Default Behavior (if `cluster_api_host` is not set):**
  - If you don't set `cluster_api_host`, the generated `kubeconfig` and `talosconfig` will use an IP address directly
    as the endpoint (controlled by `output_mode_config_cluster_endpoint`, defaulting to the first control plane's
    public IP).
  - Internal communication will still use `kube.[cluster_domain]` if `enable_alias_ip = true`.

## Additional installed software in the cluster

### [Cilium](https://cilium.io/)

- Cilium is a modern, efficient, and secure networking and security solution for Kubernetes.
- [Cilium is used as the CNI](https://www.talos.dev/v1.6/kubernetes-guides/network/deploying-cilium/) instead of the
  default Flannel.
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
- [helm](https://helm.sh/docs/intro/install/)

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

### 1. Build Talos Images with Packer

Before deploying with Terraform, you need Talos OS images (snapshots) available in your Hetzner Cloud project. This module provides Packer configurations to build these images.

- **Purpose:** Creates ARM and x86 Talos OS snapshots compatible with Hetzner Cloud.
- **Location:** All Packer-related files are in the `_packer/` directory.
- **Authentication:** Requires your Hetzner Cloud API token (set the `HCLOUD_TOKEN` environment variable or enter it when prompted by the build script).
- **Execution:** Run the `create.sh` script from the root of the repository:
  ```bash
  ./_packer/create.sh
  ```
- **Customization:** You can build standard Talos images or create custom images with additional system extensions using the Talos Image Factory.
- **Versioning:** Ensure the `talos_version` used during the Packer build matches the `talos_version` variable set in your Terraform configuration to avoid potential incompatibilities.

> **Detailed Instructions:** For comprehensive steps on building default images, using the Image Factory for custom extensions, and managing Talos versions (including how to override the default version), please refer to the **[`_packer/README.md`](_packer/README.md)** file.

### 2. Deploy the Cluster with Terraform

Use the module as shown in the following working minimal example:

> [!NOTE]
> Actually, your current IP address has to have access to the nodes during the creation of the cluster.

```hcl
module "talos" {
  source = "hcloud-talos/talos/hcloud"
  # Find the latest version on the Terraform Registry:
  # https://registry.terraform.io/modules/hcloud-talos/talos/hcloud
  version = "<latest-version>" # Replace with the latest version number

  talos_version = "v1.11.0" # The version of talos features to use in generated machine configurations

  hcloud_token            = "your-hcloud-token"
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
  # Find the latest version on the Terraform Registry:
  # https://registry.terraform.io/modules/hcloud-talos/talos/hcloud
  version = "<latest-version>" # Replace with the latest version number

  # Use versions compatible with each other and supported by the module/Talos
  talos_version      = "v1.11.0"
  kubernetes_version = "1.30.3"
  cilium_version     = "1.16.2"

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
  control_plane_allow_schedule = true

  worker_count       = 3
  worker_server_type = "cax21"

  network_ipv4_cidr = "10.0.0.0/16"
  node_ipv4_cidr    = "10.0.1.0/24"
  pod_ipv4_cidr     = "10.0.16.0/20"
  service_ipv4_cidr = "10.0.8.0/21"
}
```

### Mixed Worker Node Types

For more advanced use cases, you can define different types of worker nodes with individual configurations using the `worker_nodes` variable:

```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "<latest-version>"

  talos_version      = "v1.10.3"
  kubernetes_version = "1.30.3"

  hcloud_token            = "your-hcloud-token"
  firewall_use_current_ip = true

  cluster_name    = "mixed-cluster"
  datacenter_name = "fsn1-dc14"

  control_plane_count       = 1
  control_plane_server_type = "cx22"

  # Define different worker node types
  worker_nodes = [
    # Standard x86 workers
    {
      type  = "cx22"
      labels = {
        "node.kubernetes.io/instance-type" = "cx22"
      }
    },
    # ARM workers for specific workloads with taints
    {
      type   = "cax22"
      labels = {
        "node.kubernetes.io/arch"          = "arm64"
        "affinity.example.com" = "example"
      }
      taints = [
        {
          key    = "arm64-only"
          value  = "true"
          effect = "NoSchedule"
        }
      ]
    }
  ]
}
```

> [!NOTE]
> The `worker_nodes` variable allows you to:
> - Mix different server types (x86 and ARM)
> - Add custom labels to nodes
> - Apply taints for workload isolation
> - Control the count of each node type independently
> 
> The legacy `worker_count` and `worker_server_type` variables are still supported for backward compatibility but are deprecated in favor of `worker_nodes`.

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
# Save the configs to files
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig
```

You can then use `kubectl` and `talosctl` to interact with your cluster.
Remember to move the generated config files to a persistent location if needed (
e.g., `~/.kube/config`, `~/.talos/config`).

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

## Upgrading Kubernetes

The `kubernetes_version` variable in this Terraform module is used for the _initial deployment_ of your Kubernetes cluster.
It does **not** trigger in-place Kubernetes version upgrades on existing nodes.

To upgrade your Kubernetes cluster, you must use the `talosctl upgrade-k8s` command.

**Important Considerations for `talosctl` commands:**

- **Endpoint Resolution:** When running `talosctl` commands from outside your cluster (e.g., from your local machine),
  you might encounter issues resolving internal hostnames like `kube.cluster.local`.
  This hostname is primarily for internal cluster communication.
- **Using `--endpoint`:** To ensure reliable connectivity for `talosctl` operations (including `upgrade-k8s`,
  `version`, etc.), always specify the publicly accessible endpoint of your cluster using the `--endpoint` flag.
  This should be the `cluster_api_host` you configured,
  or the public IP address of your Floating IP/first control plane node.
- **Firewall Access:**
  Ensure your firewall rules (configured via `firewall_use_current_ip` or `firewall_talos_api_source`)
  allow access to the Talos API port (default 50000) on your control plane nodes from where you are running `talosctl`.
  Connectivity issues (e.g., `i/o timeout`) can occur if this port is blocked.

Refer to the [official Talos documentation on upgrading Kubernetes](https://www.talos.dev/v1.9/kubernetes-guides/upgrading-kubernetes/) for detailed steps and best practices.

## Known Limitations

- Changes in the `user_data` (e.g. `talos_machine_configuration`) and `image` (e.g. version upgrades with `packer`) will
  not be applied to existing nodes, because it would force a recreation of the nodes.

## Known Issues

- IPv6 dual stack is not supported by Talos yet. You can activate IPv6 with `enable_ipv6`, but it currently has no
  effect on the cluster's internal networking configuration provided by this module.
- Setting `enable_kube_span = true` might prevent the cluster from reaching a ready state in some configurations.
  Further investigation is needed.
- `403 Forbidden user` in startup log: This is a known issue related to rate limiting or IP blocking
  by `registry.k8s.io` affecting some Hetzner IP ranges.
  See [#46](https://github.com/hcloud-talos/terraform-hcloud-talos/issues/46)
  and [registry.k8s.io #138](https://github.com/kubernetes/registry.k8s.io/issues/138).

## Credits

- [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) For the inspiration and the great
  terraform module. This module is based on many ideas and code snippets from kube-hetzner.
- [Talos](https://www.talos.dev/) For the incredible OS.
- [Hetzner Cloud](https://www.hetzner.com/cloud) For the great cloud hosting.
