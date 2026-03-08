# Examples

These examples use 1Password to source the Hetzner Cloud token.
If you don’t use 1Password, remove the `onepassword` parts and provide `hcloud_token` directly.

The maintained example is [`examples/extended`](extended), which creates a Talos snapshot with `terraform-provider-imager` before provisioning the cluster.
The legacy `_packer/` workflow is deprecated and no longer maintained.
