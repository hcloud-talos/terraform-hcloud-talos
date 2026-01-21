# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Terraform module for production-ready Kubernetes clusters using Talos OS on Hetzner Cloud infrastructure. Features immutable infrastructure, HA control plane, Cilium CNI, and dual CCM setup (Hetzner + Talos).

## Key Files Structure
- `terraform.tf` - Provider configurations (Hetzner Cloud, Talos, Helm, kubectl)
- `variables.tf` - Variable definitions (13k+ lines)
- `server.tf` - Server provisioning with ARM/x86 image selection
- `network.tf` - VPC, subnets, floating IPs, alias IP setup
- `firewall.tf` - Security rules with IP auto-detection
- `talos.tf` - Talos OS configuration with KubePrism
- `talos_patch_*.tf` - Node-specific patches for control plane and workers
- `manifest_*.tf` - Kubernetes manifests for Cilium and Hcloud CCM
- `placement_groups.tf` - Spread topology for HA
- `health.tf` - Cluster health monitoring
- `outputs.tf` - Exports kubeconfig, talosconfig, cluster metadata

## Development Commands

```bash
# Format and validate
terraform fmt -recursive
terraform init
terraform validate

# Build Talos images (REQUIRED before first deployment)
./_packer/create.sh

# Quality checks
pre-commit install
pre-commit run --all-files

# Deploy
terraform plan
terraform apply

# Export configs
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig

# Access cluster
export KUBECONFIG=./kubeconfig
kubectl get nodes

# Talos management (use public endpoint)
talosctl --talosconfig ./talosconfig --endpoint <public-ip> version
```

## Configuration

### Version Compatibility (CRITICAL)
- `talos_version` must match between Packer and Terraform
- `kubernetes_version` must be compatible with `talos_version`
- `cilium_version` must be compatible with `kubernetes_version`
- Terraform >= 1.8.0 required

### Network Architecture
- `network_ipv4_cidr`: 10.0.0.0/16 (main network)
- `node_ipv4_cidr`: 10.0.1.0/24 (node subnet)
- `pod_ipv4_cidr`: 10.0.16.0/20 (pod network)
- `service_ipv4_cidr`: 10.0.8.0/21 (service network)
- Alias IP: 10.0.1.100 (when `enable_alias_ip = true`)

### Security Ports
- 6443: Kubernetes API
- 50000: Talos API
- 7445: KubePrism (internal)

### Key Variables
- `enable_floating_ip` - Floating IP for control plane
- `enable_alias_ip` - Alias IP for internal VIP
- `firewall_use_current_ip` - Auto-detect current public IP
- `firewall_kube_api_source` - Manual IP specification
- `cilium_enable_encryption` - WireGuard encryption
- `talos_control_plane_extra_config_patches` - Custom patches
- `sysctls_extra_args` - Sysctl configurations
- `kubelet_extra_args` - Kubelet customization

## Testing & Quality

```bash
terraform fmt -recursive -check -diff
terraform init && terraform validate
pre-commit run --all-files
```

### Testing Directory (.demo/)
The `.demo/` directory contains a test deployment configuration that:
- Uses the parent module (`source = "../"`)
- Configures a small demo cluster using `control_plane_nodes` and `worker_nodes`
- Integrates with 1Password for token management
- Contains its own Packer build artifacts for testing
- Has `.gitignore` set to exclude all generated files
- Provides a working example of module usage

### Pre-commit Hooks
- terraform_fmt
- terraform_docs
- terraform_tflint
- terraform_checkov

## Important Notes

### Cluster Operations
- **Upgrades**: Use `talosctl upgrade-k8s`, NOT Terraform variables
- **Node changes**: `user_data` or `image` changes = node recreation
- **Access**: Always use public endpoints for talosctl from outside

### Known Limitations
- IPv6 dual stack not supported by Talos
- KubeSpan may prevent cluster ready state
- Registry rate limiting from some Hetzner IPs
- Health check disabled (issue #7967)

### Multi-Architecture
- ARM64: CAX server types
- x86_64: CX/CPX server types
- Auto image selection based on server type
- Disable via `disable_arm` or `disable_x86`

### Debugging
```bash
# Health check
curl -k https://<control-plane-ip>:6443/version

# Talos logs
talosctl --endpoint <public-ip> logs kubelet

# Node diagnostics
talosctl --endpoint <public-ip> health

# Cilium status
kubectl -n kube-system exec ds/cilium -- cilium status
```

## CI/CD
- **dev-experience.yml**: Terraform validation (1.8.x, 1.9.x)
- **checkov.yml**: Security scanning
- **release.yml**: Semantic releases
- **Commit format**: Conventional commits enforced
