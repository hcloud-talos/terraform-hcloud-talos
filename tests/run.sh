#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cli=${IAC_CLI:-terraform}
command -v "$cli" >/dev/null
command -v talosctl >/dev/null

# Test the production inputs and generator with fixed infrastructure inputs.
cp "$root/variables.tf" "$root/talos_configuration.tf" "$root"/talos_patch_*.tf "$work/"
cp "$root/supported_versions.tf" "$root/supported_versions.json" "$work/"
cp "$root/tests/configuration/"* "$work/"
mv "$work/main.tf.tmpl" "$work/main.tf"
mkdir "$work/example-patches"
cp "$root/examples/extended/patches/kubelet/"*.yaml "$root/examples/extended/patches/registries.yaml" "$work/example-patches/"
"$cli" -chdir="$work" fmt -check
"$cli" -chdir="$work" init -backend=false -input=false -no-color
"$cli" -chdir="$work" test -no-color "$@"
