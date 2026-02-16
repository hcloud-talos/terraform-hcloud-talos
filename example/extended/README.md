# Run

This example is intended to run against the local module in this repository (see `main.tf`)

Set the 1Password provider token via `TF_VAR_op_service_account_token_test` (or replace the 1Password parts entirely).

Copy `terraform.tfvars.example` to `terraform.tfvars` (ignored by git) and set your vault + item UUIDs.

```shell
terraform init
```

```shell
terraform apply
```

```shell
terraform output --raw kubeconfig > ./kubeconfig
terraform output --raw talosconfig > ./talosconfig
```
