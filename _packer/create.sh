#!/bin/bash
set -e -u -o pipefail

command -v packer >/dev/null 2>&1 || {
    echo "packer is not installed. Install it with 'brew install packer'."
    exit 1
}

if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    read -r -p "Enter your HCLOUD_TOKEN: " hcloud_token
    export HCLOUD_TOKEN=$hcloud_token
fi
echo "Running packer build for talos-hcloud.pkr.hcl"
packer init . && packer build .
