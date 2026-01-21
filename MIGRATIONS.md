# Migrations

This document describes how to migrate between major versions of this module.


## v2 (from v1.x)


### Breaking Changes

- `control_plane_count` + `control_plane_server_type` are replaced by `control_plane_nodes`.
- `worker_count` + `worker_server_type` are removed.
- `worker_nodes` is now the only way to define workers and it represents ALL workers (not "additional workers").
- `control_plane_nodes` and `worker_nodes` now require an explicit `id` field (stable, 1-based).
- Empty control plane lists are no longer supported.
- The internal worker server resource has been consolidated:
  - removed: `hcloud_server.workers_new`
  - canonical: `hcloud_server.workers`


### General Guidance

- Always back up your Terraform state before migrating.
- The `id` field controls node identity and IP allocation. The order of the list does not matter.
- If you change ids or remove nodes without adjusting ids, Terraform may plan to replace servers.


### Step 1: Update Inputs


#### Control Planes

v1.x:

```hcl
control_plane_count       = 3
control_plane_server_type = "cax11"
```

v2:

```hcl
control_plane_nodes = [
  { id = 1, type = "cax11" },
  { id = 2, type = "cax11" },
  { id = 3, type = "cax11" },
]
```


#### Workers

v1.x legacy-only:

```hcl
worker_count       = 2
worker_server_type = "cax11"
```

v2:

```hcl
worker_nodes = [
  { id = 1, type = "cax11" }, # worker-1
  { id = 2, type = "cax11" }, # worker-2
]
```


v1.x mixed (legacy + `worker_nodes`):

```hcl
worker_count       = 2
worker_server_type = "cax11"

# In v1.x these were ADDITIONAL workers (starting at worker-3)
worker_nodes = [
  { id = 3, type = "cax11", labels = { "pool" = "extra" } }, # worker-3
]
```

v2 (single list for ALL workers, keep the same numbering/order):

```hcl
worker_nodes = [
  { id = 1, type = "cax11" },                                  # worker-1 (was legacy)
  { id = 2, type = "cax11" },                                  # worker-2 (was legacy)
  { id = 3, type = "cax11", labels = { "pool" = "extra" } },   # worker-3 (was worker_nodes)
]
```


### Step 2: Run `terraform plan`

After updating to v2 and updating your inputs, run:

```bash
terraform init
terraform plan
```


### Step 3: If Needed, Move State for Former `workers_new`

Terraform `moved` blocks cannot merge two existing resources into a single resource.

This module ships a `moved` block to automatically rename `hcloud_server.workers_new` to
`hcloud_server.workers`.

- If you only used `worker_nodes` in v1.x (no legacy `worker_count` workers), the move should apply cleanly.
- If you used BOTH legacy workers (`worker_count > 0`) AND `worker_nodes`, the destination address already
  exists in state and Terraform cannot auto-move without conflicts.

If you previously used legacy workers (`worker_count > 0`) AND `worker_nodes` in v1.x,
your state likely contains both:

- `hcloud_server.workers[...]` (legacy)
- `hcloud_server.workers_new[...]` (worker_nodes)

In that case, Terraform may warn that it “could not move” `workers_new` to `workers`
and will plan to destroy/recreate those servers.

To avoid that, move each `workers_new` instance to the corresponding `workers` address.

1) List the instances:

```bash
terraform state list | grep 'hcloud_server.workers_new'
```

2) Move each instance:

```bash
# Example (adjust module name if yours is not "talos")
terraform state mv \
  'module.talos.hcloud_server.workers_new["worker-3"]' \
  'module.talos.hcloud_server.workers["worker-3"]'
```

If you have many worker nodes, you can automate this:

```bash
for addr in $(terraform state list | grep 'hcloud_server.workers_new'); do
  terraform state mv "$addr" "${addr/workers_new/workers}"
done
```

3) Re-run plan and verify there are no server recreations:

```bash
terraform plan
```


### Step 4: Apply

Once the plan looks safe:

```bash
terraform apply
```
