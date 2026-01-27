# Migrations

This document describes how to migrate between major versions of this module.

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
