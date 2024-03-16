# terraform-hcloud-talos

This repository contains a Terraform module for creating a Kubernetes cluster with Talos in the Hetzner Cloud.

- Talos is a modern OS for Kubernetes. It is designed to be secure, immutable, and minimal.
- Hetzner Cloud is a cloud hosting provider with nice terraform support and cheap prices.

## Goals 🚀

| Goal                                                               | Status | Description                                                                                                                                                                       |
|--------------------------------------------------------------------|--------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Use private networks for the internal communication of the cluster | ✅      |                                                                                                                                                                                   |
| Do not expose the Kubernetes and Talos API to the public internet  | ❌      | Actually, the APIs are exposed to the public internet, but it is secured via the `firewall_use_current_ip` flag and a firewall rule that only allows traffic from one IP address. |
| Possibility to change alls CIDRs of the networks                   | ⁉️     | Needs to be tested.                                                                                                                                                               |

## Prerequisites

### Required Software

- [terraform](https://www.terraform.io/downloads.html)
- [packer](https://www.packer.io/downloads)

### Recommended Software

- [hcloud cli](https://github.com/hetznercloud/cli)
- [talosctl](https://www.talos.dev/v1.6/introduction/getting-started/#talosctl)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

### Hetzner Cloud

- Create a new project in the Hetzner Cloud Console
- Create a new API token in the project
- You can store the token in the environment variable `HCLOUD_TOKEN` or use it in the following commands/terraform
  files.

## Usage

### Packer

Create the talos os images (AMD and x86) via packer through running the [create.sh](packer/create.sh).
It is using the `HCLOUD_TOKEN` environment variable to authenticate against the Hetzner Cloud API and uses the project
of the token to store the images.
The talos os version is defined in the variable `talos_version`  in [talos-hcloud.pkr.hcl](packer/talos-hcloud.pkr.hcl).

```bash
./packer/create.sh
```

### Terraform
Use the module as shown in the following example:
```hcl
module "talos" {
  source  = "hcloud-talos/talos/hcloud"
  version = "1.0.0"

  hcloud_token = "" // Your hcloud token

  cluster_name    = "talos-cluster"
  datacenter_name = "fsn1-dc14"

  ssh_public_key = "" // e.g. file("~/.ssh/id_rsa.pub")

  firewall_use_current_ip = true // allow traffic only from the current IP address

  control_plane_count       = 3 // number of control planes to create
  control_plane_server_type = "cax21" // server type for the control plane

  worker_count       = 3 // number of worker to create
  worker_server_type = "cax21" // server type for the worker
}
```

## Credits

- [kube-hetzner](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner) For the inspiration and the great
  terraform module. This module is based on many ideas and code snippets from kube-hetzner.
- [Talos](https://www.talos.dev/) For the incredible OS.
- [Hetzner Cloud](https://www.hetzner.com/cloud) For the great cloud hosting.
