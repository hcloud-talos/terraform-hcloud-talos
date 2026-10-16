# Run

This example is intended to run against the local module in this repository (see `main.tf`).
It uses `terraform-provider-imager` to create the Talos snapshot that is then passed into the module via `talos_image_id_x86`.

This example uses Talos `v1.14.3`, Kubernetes `1.35.0`, and Cilium `1.20.3`.
The kubelet patches use the Talos 1.14 document format. If you select Talos 1.13,
convert those patches to `machine.kubelet.extraArgs` as described in
[MIGRATIONS.md](../../MIGRATIONS.md). See the
[support policy](../../SUPPORTED_VERSIONS.md) for the accepted versions.

Set the 1Password provider token via `TF_VAR_op_service_account_token_test` (or replace the 1Password parts entirely and configure `hcloud` plus `imager` directly).

Copy `terraform.tfvars.example` to `terraform.tfvars` (ignored by git) and set your vault + item UUIDs.

`terraform apply` will first upload the Talos disk image to Hetzner Cloud and create a snapshot, so the initial apply can take several minutes.

```shell
terraform init -upgrade
```

```shell
terraform apply
```

```shell
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig
```
