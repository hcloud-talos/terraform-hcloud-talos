# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform module that creates production-ready Kubernetes clusters using Talos OS on Hetzner Cloud infrastructure. It deploys secure, immutable clusters with comprehensive networking, security, and high availability features.

## Architecture

### Core Components
- **Control Plane**: 1, 3, or 5 control plane nodes (odd numbers only) running Talos OS
- **Worker Nodes**: Configurable number of worker nodes
- **Networking**: Private Hetzner Cloud networks with public API access via firewall rules
- **CNI**: Cilium for advanced networking and security features
- **Cloud Integration**: Hetzner Cloud Controller Manager for native cloud features

### Key Files Structure
- `terraform.tf` - Provider configurations (Hetzner Cloud, Talos, Helm, kubectl)
- `variables.tf` - Comprehensive variable definitions (13k+ lines)
- `server.tf` - Server provisioning for control plane and worker nodes
- `network.tf` - VPC, subnets, floating IPs setup
- `firewall.tf` - Security rules and firewall configuration
- `talos.tf` - Talos OS configuration and bootstrapping
- `talos_patch_*.tf` - Node-specific Talos configurations
- `manifest_*.tf` - Kubernetes manifests for Cilium and Hcloud CCM

## Development Commands

### Essential Commands
```bash
# Format Terraform code
terraform fmt -recursive

# Validate configuration
terraform init
terraform validate

# Build Talos images (required before first deployment)
./_packer/create.sh

# Install and run pre-commit hooks
pre-commit install
pre-commit run --all-files
```

### Packer Image Building
Located in `_packer/` directory. Must be run before first Terraform deployment:
```bash
# Build Talos OS images for both ARM64 and x86_64
./_packer/create.sh
```

### Testing and Quality Assurance
- **Terraform Validation**: `terraform init && terraform validate`
- **Security Scanning**: Checkov runs in CI, can be run locally if installed
- **Code Formatting**: `terraform fmt -recursive` and Prettier
- **Pre-commit Hooks**: Run automatically on commit, manually with `pre-commit run --all-files`

## Configuration Management

### Version Compatibility
Critical version alignments required:
- `talos_version` must match between Packer build and Terraform deployment
- `kubernetes_version` must be compatible with `talos_version`
- `cilium_version` must be compatible with `kubernetes_version`

### Network Configuration
All network CIDRs are customizable:
- `network_ipv4_cidr` - Main network CIDR
- `node_ipv4_cidr` - Node subnet CIDR
- `pod_ipv4_cidr` - Pod network CIDR
- `service_ipv4_cidr` - Service network CIDR

### Security Configuration
- Firewall rules restrict API access to specific IPs
- `firewall_use_current_ip = true` automatically uses current public IP
- Manual IP specification via `firewall_kube_api_source` and `firewall_talos_api_source`

## Deployment Workflow

1. **Image Building**: Run `_packer/create.sh` to build Talos OS images
2. **Configuration**: Set required variables (hcloud_token, cluster_name, etc.)
3. **Deployment**: Run `terraform plan` and `terraform apply`
4. **Config Export**: Extract kubeconfig and talosconfig from Terraform outputs
5. **Access**: Use kubectl and talosctl with exported configurations

## CI/CD Integration

### GitHub Actions Workflows
- **dev-experience.yml**: Terraform validation on multiple versions (1.8.x, 1.9.x)
- **checkov.yml**: Security scanning with SARIF output
- **release.yml**: Automated semantic releases

### Code Quality Tools
- **Pre-commit hooks**: terraform_fmt, terraform_docs, terraform_tflint, terraform_checkov
- **Conventional Commits**: Enforced via commitlint
- **Semantic Release**: Automated versioning based on commit messages

## Important Notes

### Cluster Upgrades
- Kubernetes upgrades must be performed using `talosctl upgrade-k8s`, not by changing Terraform variables
- Changes to `user_data` or `image` require node recreation
- Always use publicly accessible endpoints when running talosctl from outside the cluster

### Known Limitations
- IPv6 dual stack not yet supported by Talos
- KubeSpan may prevent cluster ready state in some configurations
- Rate limiting issues with registry.k8s.io from some Hetzner IP ranges

### Multi-Architecture Support
- Supports both ARM64 and x86_64 server types
- Separate Packer builds create images for both architectures
- Server type selection determines architecture (e.g., "cax11" for ARM64, "cx11" for x86_64)
