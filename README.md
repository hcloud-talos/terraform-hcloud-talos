# terraform-hcloud-talos
This repository contains a Terraform module for creating a Kubernetes cluster with Talos in the Hetzner Cloud.

- Talos is a modern OS for Kubernetes. It is designed to be secure, immutable, and minimal.

- Hetzner Cloud is a cloud hosting provider with nice terraform support and cheap prices.

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

## Usage
### Packer
Create the talos os image via packer through running the [create.sh](packer/create.sh).
The talos os version is defined in the variable `talos_version`  in [talos-hcloud.pkr.hcl](packer/talos-hcloud.pkr.hcl).

```bash
./packer/create.sh
```

### Terraform
Use the module in your terraform code. An example can be found in the [examples](examples/main.tf).
