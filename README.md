<div align="center">
  <br>
  <img src="https://github.com/hcloud-talos/terraform-hcloud-talos/blob/main/.idea/icon.png?raw=true" alt="Terraform - Hcloud - Talos" width="200"/>
  <h1 style="margin-top: 0; padding-top: 0;">Terraform - Hcloud - Talos</h1>
  <img alt="GitHub Release" src="https://img.shields.io/github/v/release/hcloud-talos/terraform-hcloud-talos?logo=github">
  <p>
    <a href="https://hetzner.cloud/?ref=9EF3RYocQW8y">New to Hetzner? Get 20€ credit</a>
  </p>
  <p>
    <a href="https://www.buymeacoffee.com/mrclrchtr"><img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=mrclrchtr&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" alt="Buy me a coffee" /></a>
  </p>
  <p>If this module saved you time or money, consider supporting ongoing maintenance.</p>
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

  | Goals                                                              | Status | Description                                                                                                                                                                                                   |
  |--------------------------------------------------------------------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
  | Production ready                                                   | ✅      | Designed around the recommendations from the [Talos Production Clusters](https://docs.siderolabs.com/talos/latest/getting-started/prodnotes). You still need to handle DNS/LB setup, backups, and operations. |
  | Use private networks for the internal communication of the cluster | ✅      | Hetzner Cloud Networks are used for internal node-to-node communication.                                                                                                                                      |
  | Secure API Exposure                                                | ✅      | The Kubernetes and Talos APIs are exposed to the public internet but secured via firewall rules. By default (`firewall_use_current_ip = true`), only traffic from your current IP address is allowed.         |
  | Possibility to change all CIDRs of the networks                    | ✅      | All network CIDRs (network, node, pod, service) can be customized.                                                                                                                                            |
  | Configure the Cluster optimally to run in the Hetzner Cloud        | ✅      | This includes manual configuration of the network devices and not via DHCP, provisioning of Floating IPs (VIP), etc.                                                                                          |

## Information about the Module

- A lot of information can be found directly in the descriptions of the variables.
- You can configure the module to create a cluster with 1, 3 or 5 control planes and n workers or only the control
  planes.
- It allows scheduling pods on the control planes if no workers are created.
- It has [Multihoming](https://docs.siderolabs.com/talos/latest/getting-started/prodnotes/#multihoming) configuration (etcd and kubelet
  listen on public and private IP).
- It uses [KubePrism](https://docs.siderolabs.com/talos/latest/kubernetes-guides/advanced-guides/kubeprism)
  for internal API server access (`127.0.0.1:7445`) from within the cluster nodes.
- **Public API Endpoint:**
  - You can define a stable public endpoint for your cluster using the `cluster_api_host` variable (
    e.g., `kube.mydomain.com`).
  - If you set `cluster_api_host`, you **must** create a DNS A record for this hostname pointing to the public IP
     address you want clients to use. This could be:
     - The Hetzner Floating IP (if `enable_floating_ip = true`).
     - The IP of an external TCP load balancer you configure separately (pass-through, no TLS termination).
     - The public IP of a specific control plane node (less recommended for multi-node control planes).
  - The generated `kubeconfig` will use this hostname if `kubeconfig_endpoint_mode = "public_endpoint"`.
  - The generated `talosconfig` will always use direct per-node IPs as endpoints (see `talosconfig_endpoints_mode`).
  - **Note:** `cluster_api_host` is the Kubernetes API endpoint (TCP/6443). Talos API access uses TCP/50000 and is
    configured separately via `talosconfig_endpoints_mode`.
- **Internal API Endpoint:**
  - For internal communication _between cluster nodes_, Talos uses an internal API hostname.
    By default this is `kube.[cluster_domain]` (e.g., `kube.cluster.local`), but you can override it via
    `cluster_api_host_private`.
  - If `enable_alias_ip = true` (the default), this module automatically configures `/etc/hosts` entries on each node
    to resolve the internal API hostname to the _private_ alias IP (`10.0.1.100` by default). This ensures reliable
    internal communication.
  - If `enable_alias_ip = false`, you must provide a working private DNS record for `cluster_api_host_private` yourself
    (or accept the single-node fallback when using a single control plane).
  - If you access the cluster from a workstation over VPN/private networking, consider creating a private (split-horizon)
    DNS record for a resolvable name (e.g., `kube.example.com` -> `10.0.1.100`) and set `cluster_api_host_private` to
    that name. This prevents client-side DNS failures when Talos embeds the internal endpoint into kubeconfig.
- **Default Behavior (if `cluster_api_host` is not set):**
  - If you don't set `cluster_api_host`, the generated `kubeconfig` will use an IP address directly as the endpoint
    (controlled by `kubeconfig_endpoint_mode`, defaulting to the first control plane's public IP or the Floating IP).
  - `talosconfig` endpoints are configured separately via `talosconfig_endpoints_mode`.
  - Internal communication will still use the internal API hostname (defaults to `kube.[cluster_domain]`) if `enable_alias_ip = true`.

## Additional installed software in the cluster

### [Cilium](https://cilium.io/)

- Cilium is a modern, efficient, and secure networking and security solution for Kubernetes.
- [Cilium is used as the CNI](https://docs.siderolabs.com/talos/latest/kubernetes-guides/network/deploying-cilium) instead of the
  default Flannel.
- It provides a lot of features like Network Policies, Load Balancing, and more.

> [!IMPORTANT]
> The Cilium version (`cilium_version`) has to be compatible with the Kubernetes (`kubernetes_version`) version.

> [!TIP]
> After initial cluster bootstrap, you can set `deploy_cilium = false` (and `deploy_prometheus_operator_crds = false` if you used it) to hand off management to GitOps tools (e.g., Argo CD, Flux).
> Run `terraform apply` once after toggling: Terraform removes these resources from state without deleting them from the cluster.
> This works because the module uses `kubectl_manifest` with `apply_only = true`, so Terraform does not delete these manifests on destroy.

### [Hcloud Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager)

- Updates the `Node` objects with information about the server from the Cloud, like instance Type, Location, Server ID, IPs.
- Cleans up stale `Node` objects when the server is deleted in the API.
- Routes traffic to the pods through Hetzner Cloud Networks. Removes one layer of indirection.
- Watches Services with `type: LoadBalancer` and creates Hetzner Cloud Load Balancers for them, adds Kubernetes
  Nodes as targets for the Load Balancer.

> [!TIP]
> After initial cluster bootstrap, you can set `deploy_hcloud_ccm = false` to hand off management to GitOps tools (e.g., Argo CD, Flux).
> Run `terraform apply` once after toggling: Terraform removes these resources from state without deleting them from the cluster.
> This works because the module uses `kubectl_manifest` with `apply_only = true`, so Terraform does not delete these manifests on destroy.

### [Talos Cloud Controller Manager](https://github.com/siderolabs/talos-cloud-controller-manager)

- [Applies labels to the nodes](https://github.com/siderolabs/talos-cloud-controller-manager?tab=readme-ov-file#node-initialize).
- [Validates and approves node CSRs](https://github.com/siderolabs/talos-cloud-controller-manager?tab=readme-ov-file#node-certificate-approval).
- In DaemonSet mode: CCM will use hostNetwork and current node to access kubernetes/talos API

### [Tailscale](https://tailscale.com/) (Optional)

- The Talos Image **MUST** be created with the [tailscale extension](https://github.com/siderolabs/extensions/blob/main/network/tailscale/README.md) when `tailscale.enabled` is set to true.
- Tailscale can be enabled as a system extension on all nodes
- Provides secure, encrypted networking between your nodes and other devices in your Tailscale network
- Makes cluster nodes accessible via their Tailscale IPs from anywhere
- Requires a valid Tailscale auth key to be provided in the configuration

## Prerequisites

### Required Software

- [terraform](https://www.terraform.io/downloads.html)
- [packer](https://www.packer.io/downloads)
- [helm](https://helm.sh/docs/intro/install/)

### Recommended Software

- [hcloud cli](https://github.com/hetznercloud/cli)
- [talosctl](https://docs.siderolabs.com/talos/latest/introduction/getting-started/#talosctl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Hetzner Cloud

> [!TIP]
> New to Hetzner Cloud? Use this [referral link](https://hetzner.cloud/?ref=9EF3RYocQW8y) to get **20€ credit** and
> support this project.

- Create a new project in the Hetzner Cloud Console
- Create a new API token in the project
- You can store the token in the environment variable `HCLOUD_TOKEN` or use it in the following commands/terraform
  files.

## Usage

### 1. Build Talos Images with Packer (Optional)

> [!TIP]
> You can also use official Hetzner Talos images directly by setting `talos_image_id_x86` and/or `talos_image_id_arm`.
> Check the Hetzner changelog for current Talos image IDs: https://docs.hetzner.cloud/changelog

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
> Verify version compatibility before deploying:
> - [Talos Support Matrix](https://docs.siderolabs.com/talos/latest/getting-started/support-matrix)
> - [Cilium Compatibility](https://docs.cilium.io/en/stable/operations/system_requirements/#kubernetes-versions)

> [!NOTE]
> Actually, your current IP address has to have access to the nodes during the creation of the cluster.

```hcl
module "talos" {
  source = "hcloud-talos/talos/hcloud"
  # Find the latest version on the Terraform Registry:
  # https://registry.terraform.io/modules/hcloud-talos/talos/hcloud
  version = "<latest-version>" # Replace with the latest version number

  talos_version = "v1.12.2" # The version of talos features to use in generated machine configurations

  # Optional: use official Hetzner Talos image IDs (no custom Packer image required)
  # talos_image_id_x86 = "<x86-image-id>"
  # talos_image_id_arm = "<arm-image-id>"

  hcloud_token            = "your-hcloud-token"
  # If true, the current IP address will be used as the source for the firewall rules.
  # ATTENTION: to determine the current IP, a request to a public service (https://ipv4.icanhazip.com) is made.
  # If false, you have to provide your public IP address (as list) in the variable `firewall_kube_api_source` and `firewall_talos_api_source`.
  firewall_use_current_ip = true

  cluster_name    = "dummy.com"
  location_name   = "fsn1"

  control_plane_nodes = [
    {
      id   = 1
      type = "cax11"
    }
  ]
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
  talos_version      = "v1.12.2"
  kubernetes_version = "1.35.0"
  cilium_version     = "1.16.2"

  hcloud_token = "your-hcloud-token"

  cluster_name     = "dummy.com"
  cluster_domain   = "cluster.dummy.com.local"
  cluster_api_host = "kube.dummy.com"

  firewall_use_current_ip = false
  firewall_kube_api_source = ["your-ip"]
  firewall_talos_api_source = ["your-ip"]

  location_name = "fsn1"

  control_plane_nodes = [
    {
      id   = 1
      type = "cax11"
    },
    {
      id   = 2
      type = "cax11"
    },
    {
      id   = 3
      type = "cax11"
    }
  ]
  control_plane_allow_schedule = true

  worker_nodes = [
    {
      id   = 1
      type = "cax21"
    },
    {
      id   = 2
      type = "cax21"
    },
    {
      id   = 3
      type = "cax21"
    }
  ]

  network_ipv4_cidr = "10.0.0.0/16"
  node_ipv4_cidr    = "10.0.1.0/24"
  pod_ipv4_cidr     = "10.0.16.0/20"
  service_ipv4_cidr = "10.0.8.0/21"
  
  # Enable Tailscale integration
  tailscale = {
    enabled  = true
    auth_key = "tskey-auth-xxxxxxxxxxxx" # Your Tailscale auth key
  }
}
```

### Endpoint Configuration Examples

These snippets show only the endpoint- and access-related settings. Combine them with the required module inputs from the examples above.

#### VPN-only (private kubeconfig/talosconfig)

Use this when your workstation/CI reaches the nodes via VPN/private networking, but the public firewall should still allow your current public IP (so Terraform can bootstrap and manage the cluster).

```hcl
firewall_use_current_ip = true

# Use the private VIP via a VPN-resolvable hostname (split-horizon DNS).
enable_alias_ip            = true # default
cluster_api_host_private   = "kube.vpn.example.com" # -> 10.0.1.100 (private VIP)
kubeconfig_endpoint_mode   = "private_endpoint"
talosconfig_endpoints_mode = "private_ip"
```

#### Floating IP (public VIP)

Use this when you want a public, stable Kubernetes API endpoint without running your own load balancer.

```hcl
firewall_use_current_ip = true

enable_floating_ip         = true
kubeconfig_endpoint_mode   = "public_ip" # uses the Floating IP for HA control planes
talosconfig_endpoints_mode = "public_ip"
```

#### External TCP load balancer + public DNS (recommended for HA)

Use this when you have a dedicated TCP (L4) load balancer pointing to all control planes on port 6443.

```hcl
firewall_use_current_ip    = true

cluster_api_host           = "kube.example.com" # -> LB IP/DNS
kubeconfig_endpoint_mode   = "public_endpoint"
talosconfig_endpoints_mode = "public_ip"
```

#### Split-horizon: public kubeconfig + private node endpoint

Use this when nodes should use a private VIP/hostname, but your kubeconfig should point to a public DNS/LB.

```hcl
firewall_use_current_ip    = true

enable_alias_ip            = true # private VIP for nodes
cluster_api_host_private   = "kube.internal.example.com" # -> 10.0.1.100 (private VIP)

cluster_api_host           = "kube.example.com" # -> public Floating IP or TCP LB
kubeconfig_endpoint_mode   = "public_endpoint"
talosconfig_endpoints_mode = "public_ip"
```

### Mixed Worker Node Types

For more advanced use cases, you can define different types of worker nodes with individual configurations using the `worker_nodes` variable:

```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "<latest-version>"

  talos_version      = "v1.12.2"
  kubernetes_version = "1.35.0"

  hcloud_token            = "your-hcloud-token"
  firewall_use_current_ip = true

  cluster_name    = "mixed-cluster"
  location_name = "fsn1"

  control_plane_nodes = [
    {
      id   = 1
      type = "cx22"
    }
  ]

  # Define different worker node types
  worker_nodes = [
    # Standard x86 workers
    {
      id   = 1
      type = "cx22"
      labels = {
        "node.kubernetes.io/instance-type" = "cx22"
      }
    },
    # ARM workers for specific workloads with taints
    {
      id    = 2
      type  = "cax21"
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
> - Control the number of nodes by adding/removing entries
> - Keep stable node identity by setting `id` (1..N)

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

### Tailscale Integration

This module supports configuring Tailscale on your cluster nodes, which provides secure networking capabilities:

```hcl
tailscale = {
  enabled  = true
  auth_key = "tskey-auth-xxxxxxxxxxxx" # Your Tailscale auth key
}
```

When Tailscale is enabled:
- Each node will run Tailscale as a system extension
- Nodes will automatically connect to your Tailscale network
- Cilium's loadBalancer acceleration is set to "best-effort" mode for compatibility with Tailscale
- You can access your cluster nodes directly via their Tailscale IPs

> [!NOTE]
> You must provide a valid Tailscale auth key when enabling this feature. Auth keys can be generated in the Tailscale admin console.
> For more information, see the [Tailscale documentation on authentication keys](https://tailscale.com/kb/1085/auth-keys/).

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

- **Talos API Endpoints:** `talosctl` talks to the Talos API (TCP/50000). Use `talosconfig_endpoints_mode = "public_ip"`
  when running `talosctl` from outside, or `"private_ip"` when running over VPN/private networking.
- **Avoid VIP/Load-Balanced Endpoints:** Talos recommends using direct per-node IPs as endpoints in `talosconfig` (not a
  VIP), because VIP availability depends on etcd health.
- **Firewall Access:**
  Ensure your firewall rules (configured via `firewall_use_current_ip` or `firewall_talos_api_source`)
  allow access to the Talos API port (default 50000) on your control plane nodes from where you are running `talosctl`.
  Connectivity issues (e.g., `i/o timeout`) can occur if this port is blocked.

Refer to the [official Talos documentation on upgrading Kubernetes](https://docs.siderolabs.com/talos/latest/kubernetes-guides/upgrading-kubernetes) for detailed steps and best practices.

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

## Support

If this module saved you time or helped you run Talos on Hetzner more reliably, consider supporting ongoing
maintenance:

- [GitHub Sponsors](https://github.com/sponsors/hcloud-talos)
- [Buy Me a Coffee](https://buymeacoffee.com/mrclrchtr)
- [Hetzner Cloud referral (20€ credit)](https://hetzner.cloud/?ref=9EF3RYocQW8y)

Sponsorship is about sustainability and public appreciation, not a paid support contract or SLA. Sponsors can be
acknowledged publicly via GitHub Sponsors.

## Credits

- [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) For the inspiration and the great
  terraform module. This module is based on many ideas and code snippets from kube-hetzner.
- [Talos](https://docs.siderolabs.com/talos/latest/overview/what-is-talos) For the incredible OS.
- [Hetzner Cloud](https://www.hetzner.com/cloud) For the great cloud hosting.
