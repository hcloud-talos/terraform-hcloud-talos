# Migrations

This document describes how to migrate between major versions of this module.

## v5 (from v4.x)

### Breaking Changes

- The `talos_machine_bootstrap` resource is replaced by `talos_cluster`. On the first `terraform apply` after
  upgrading, Terraform will plan to destroy `talos_machine_bootstrap.this[0]` and create `talos_cluster.this`. This
  is safe: both resources' `Delete` is a no-op (verified in the provider source), and the Bootstrap RPC
  `talos_cluster` issues on create is idempotent against an already-bootstrapped cluster (`codes.AlreadyExists` is
  treated as success).
- `kubernetes_version` is no longer bootstrap-only: changing it now runs a live `upgrade-k8s` through `talos_cluster`
  on `terraform apply`. This replaces the v4 guidance that Terraform does not upgrade Kubernetes on existing nodes.
  **Before upgrading this module**, make sure `kubernetes_version` in your existing configuration matches the
  version your cluster is actually running — otherwise the next apply will immediately kick off an unintended
  Kubernetes upgrade. See "Upgrading Kubernetes" in the README for details.
- Talos OS upgrades are unchanged: changing `talos_version` still does not upgrade existing nodes.

### General Guidance

- Run `terraform plan` first and confirm the only changes are the `talos_machine_bootstrap` → `talos_cluster`
  swap (and, if you intend it, a `kubernetes_version` upgrade) before applying.

## Image and ISO inputs

Use the object inputs for image and ISO IDs that are unknown during planning.
This includes snapshots created by `terraform-provider-imager` in the same apply.
Change this:

```hcl
talos_image_id_x86 = imager_image.talos_x86.id
```

To this:

```hcl
talos_image_x86 = {
  id = imager_image.talos_x86.id
}
```

The same change applies to `talos_image_arm`, `talos_iso_x86`, and `talos_iso_arm`.
The object must be known during planning; only its ID can remain unknown. The ID
must be a numeric string, not null or empty. No resource addresses change.

The legacy scalar inputs remain supported for fixed IDs. Do not combine an
object input with another source for the same architecture. ARM and x86 can use
different sources.

If you set `disable_arm` or `disable_x86` only to avoid the unknown-ID error,
you can remove that flag for the architecture with the new object input. Keep
flags for unused architectures if you need to skip their image lookup. These
flags skip automatic lookup and ISO attachment; they do not disable nodes or
prevent the use of supplied image IDs.

## v4 (from v3.x)

Version 4.0.0 adds explicit Talos and Kubernetes version limits and the Talos 1.14
configuration format. See the [v4.0.0 release notes](https://github.com/hcloud-talos/terraform-hcloud-talos/releases/tag/v4.0.0)
for the complete change summary.

### Breaking changes

- Talos is limited to stable `v1.13.11` or later 1.13 patches, and `v1.14.3` or
  later 1.14 patches. Older versions and unapproved minor series are rejected.
- Kubernetes must match the selected Talos series. See
  [SUPPORTED_VERSIONS.md](SUPPORTED_VERSIONS.md) for the exact limits.
- Use a `v` prefix for Talos, but not for Kubernetes. Both inputs require a patch
  number. Prereleases and build metadata are rejected.
- The Talos provider is limited to `0.12.x`.
- Default snapshot lookup now requires `os=talos` and
  `version=<talos_version>` labels. Explicit image and ISO IDs still bypass the
  lookup; check their versions yourself.
- The Cilium default changes from `1.16.2` to `1.20.3`. Review its upgrade guide
  and your Helm values. Pin `cilium_version` if you manage this upgrade separately.
  Cilium compatibility is not enforced by the Talos/Kubernetes checks. Cilium 1.20
  documents tested support for Kubernetes 1.33–1.36, not every version supported
  by Talos.
- The deprecated Packer template applies the same Talos limits and defaults to
  `v1.14.3`. Update local `hcloud.auto.pkrvars.hcl` files that select older versions.
  Use `terraform-provider-imager` for new image builds.
- Talos 1.14 extra patches must not set legacy fields that conflict with the new
  generated documents.

### Supported versions in v4.0.0

| Talos series | Minimum Talos version | Kubernetes range |
| --- | --- | --- |
| 1.13 | `v1.13.11` | `>= 1.31.0, < 1.36.99` |
| 1.14 | `v1.14.3` | `>= 1.32.0, < 1.37.99` |

Later stable Talos patches within these two minor series are accepted. New minor
and major series require explicit module support. The boot image must match
`talos_version`.

### Upgrade procedure

1. Back up Terraform state and etcd. Check the Talos, Kubernetes, and Cilium
   upgrade paths.
2. Upgrade existing nodes with the Talos tools. Changing `talos_version` or
   `kubernetes_version` in Terraform does not upgrade those nodes. Server
   lifecycle rules ignore changes to `user_data`, `image`, and `iso`.
3. Build or select images that match the supported Talos version for new nodes.
4. Set the module version to `4.0.0`, set supported version inputs, and update
   custom patches. Review `cilium_version` explicitly. Run `terraform init -upgrade`
   to select the required provider.
5. Review `terraform plan`. Do not apply an unexpected server replacement.
6. Apply machine configuration to existing nodes through your normal Talos
   configuration process. This module supplies configuration through server
   `user_data`; it does not apply changes to existing nodes.

### Custom patches for Talos 1.14

For Talos 1.13, existing legacy patches remain valid. For Talos 1.14, change this:

```yaml
machine:
  kubelet:
    extraArgs:
      max-pods: "80"
```

To this:

```yaml
apiVersion: v1alpha1
kind: KubeletConfig
extraArgs:
  max-pods: "80"
```

Other relevant mappings are:

| Legacy field | Talos 1.14 document and field |
| --- | --- |
| `machine.nodeLabels` | `KubeNodeConfig.labels` |
| `machine.kubelet.nodeIP` | `KubeNodeConfig.nodeIP` |
| `machine.kubelet.extraConfig` | `KubeletConfig.config` |
| `machine.features.hostDNS` | `ResolverConfig.hostDNS` |
| `machine.install.image` | `UnattendedInstallConfig.installer.image` |
| Installer hostname kernel argument | `HostnameConfig.hostname` |
| `cluster.network` | `KubeNetworkConfig` |
| `cluster.apiServer.extraArgs` | `KubeAPIServerConfig.extraArgs` |
| `cluster.controllerManager.extraArgs` | `KubeControllerManagerConfig.extraArgs` |
| `cluster.scheduler.extraArgs` | `KubeSchedulerConfig.extraArgs` |

Talos 1.14 installation selects `/dev/sda`, as the Packer build does. If you need
another disk, override `UnattendedInstallConfig.provisioning.diskSelector.match`.

For clusters without workers, the module removes the load balancer exclusion
label and the default control-plane scheduling restriction in both formats.
Custom taints remain in place. Do not remove the label patch as a workaround for
issue #620; Talos 1.14 needs the patch in the new document.

## v3 (from v2.x)

### Breaking Changes

- `datacenter_name` variable has been renamed to `location_name` and now uses location names instead of datacenter names.
  - Old format: `"fsn1-dc14"`, `"nbg1-dc3"`, `"hel1-dc2"`, `"ash-dc1"`, `"hil-dc1"`
  - New format: `"fsn1"`, `"nbg1"`, `"hel1"`, `"ash"`, `"hil"`, `"sin"`
- `control_plane_count` + `control_plane_server_type` are replaced by `control_plane_nodes`.
- `worker_count` + `worker_server_type` are removed.
- `worker_nodes` is now the only way to define workers and it represents ALL workers.
- `control_plane_nodes` and `worker_nodes` now require an explicit `id` field (stable, 1-based).
- Empty control plane lists are no longer supported.
- `output_mode_config_cluster_endpoint` has been removed and replaced by:
  - `kubeconfig_endpoint_mode` (`public_ip`, `private_ip`, `public_endpoint`, `private_endpoint`)
  - `talosconfig_endpoints_mode` (`public_ip`, `private_ip`)
- `talosconfig` endpoints are now always direct per-node IPs (Talos API). The module no longer supports writing a VIP or
  load-balanced hostname into `talosconfig` endpoints (this is not recommended by Talos).
- For HA control planes (`control_plane_nodes` > 1):
  - `kubeconfig_endpoint_mode = "public_ip"` requires `enable_floating_ip = true`
  - `kubeconfig_endpoint_mode = "private_ip"` requires `enable_alias_ip = true`
- `kubeconfig_data.host` now matches the generated kubeconfig endpoint (it is no longer always the public IP).
- `kubernetes_version` is now required (no default value). Choose a version compatible with your Talos version:
  https://docs.siderolabs.com/talos/latest/getting-started/support-matrix

### General Guidance

- Always back up your Terraform state before migrating.
- The `id` field controls node identity and IP allocation. The order of the list does not matter.
- If you change ids or remove nodes without adjusting ids, Terraform may plan to replace servers.

### Migration Steps

1) Rename datacenter to location:

v2.x:

```hcl
datacenter_name = "fsn1-dc14"
```

v3:

```hcl
location_name = "fsn1"
```

The location name is derived from the first part of the datacenter name:
- `fsn1-dc14` → `fsn1`
- `nbg1-dc3` → `nbg1`
- `hel1-dc2` → `hel1`
- `ash-dc1` → `ash`
- `hil-dc1` → `hil`

2) Replace count-based nodes with explicit node lists:

Control planes (v2.x):

```hcl
control_plane_count       = 3
control_plane_server_type = "cax11"
```

Control planes (v3):

```hcl
control_plane_nodes = [
  { id = 1, type = "cax11" },
  { id = 2, type = "cax11" },
  { id = 3, type = "cax11" },
]
```

Workers (v2.x):

```hcl
worker_count       = 2
worker_server_type = "cax11"
```

Workers (v3):

```hcl
worker_nodes = [
  { id = 1, type = "cax11" }, # worker-1
  { id = 2, type = "cax11" }, # worker-2
]
```

3) Set `kubernetes_version` explicitly (required in v3):

v2.x (relied on default):

```hcl
# kubernetes_version had a default of "1.30.3"
```

v3 (must be set):

```hcl
kubernetes_version = "1.35.0"  # Choose version compatible with your Talos version
```

Check the support matrix for compatible versions:
https://docs.siderolabs.com/talos/latest/getting-started/support-matrix

4) Remove `output_mode_config_cluster_endpoint` from your inputs.
5) Choose the `kubeconfig` endpoint:
   - If you previously used `output_mode_config_cluster_endpoint = "cluster_endpoint"`, set:
      - `kubeconfig_endpoint_mode = "public_endpoint"`
      - `cluster_api_host = "kube.example.com"`
    - If you access the cluster over VPN/private networking, set:
      - `kubeconfig_endpoint_mode = "private_ip"` (alias IP / VIP) **or**
      - `kubeconfig_endpoint_mode = "private_endpoint"` with `cluster_api_host_private`
6) Choose `talosconfig` endpoints (Talos API):
   - `talosconfig_endpoints_mode = "public_ip"` when running `talosctl` from outside
   - `talosconfig_endpoints_mode = "private_ip"` when running `talosctl` over VPN/private networking
7) Run `terraform plan` and verify the rendered endpoints match your expected access pattern.
8) Apply once the plan looks safe:

```bash
terraform apply
```
