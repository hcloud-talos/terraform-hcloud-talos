#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cli=${IAC_CLI:-terraform}
command -v "$cli" >/dev/null

# Test production image selection without cloud resources or cluster access.
mkdir "$work/module"
cp "$root/images.tf" "$root/variables.tf" "$root/supported_versions.tf" "$root/supported_versions.json" "$work/module/"
cp "$root/tests/images/module.tf.tmpl" "$work/module/main.tf"
cp "$root/tests/images/main.tf.tmpl" "$work/main.tf"
cp "$root/tests/images/"*.tftest.hcl "$work/"
"$cli" -chdir="$work" fmt -recursive -check
"$cli" -chdir="$work" init -backend=false -input=false -no-color
"$cli" -chdir="$work" test -no-color "$@"
