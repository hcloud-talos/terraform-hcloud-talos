#!/bin/bash
# This script builds Hetzner Cloud images for Talos using Packer.
#
# Usage:
#   ./create.sh              # Build generic images (no role label)
#   ./create.sh --roles      # Build role-specific images (control-plane and worker)
#   ./create.sh control-plane # Build only control-plane images
#   ./create.sh worker        # Build only worker images

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# Pipelines return the exit status of the last command to exit non-zero.
set -euo pipefail

# Check if packer is installed
command -v packer >/dev/null 2>&1 || {
    echo >&2 "Error: packer is not installed."
    echo >&2 "Install it via https://www.packer.io/downloads or 'brew install packer' on macOS."
    exit 1
}

# Check if curl is installed (needed for schematic ID generation)
command -v curl >/dev/null 2>&1 || {
    echo >&2 "Error: curl is not installed."
    exit 1
}

# Check if jq is installed (needed for parsing schematic response)
command -v jq >/dev/null 2>&1 || {
    echo >&2 "Error: jq is not installed."
    echo >&2 "Install it via 'brew install jq' on macOS or 'apt-get install jq' on Debian/Ubuntu."
    exit 1
}

# Check if HCLOUD_TOKEN is set, otherwise prompt the user securely
if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    echo "Hetzner Cloud API token (HCLOUD_TOKEN) is not set."
    # Use read -s for silent input (hides the token)
    read -s -r -p "Enter your HCLOUD_TOKEN: " hcloud_token
    echo # Add a newline after the hidden input
    if [[ -z "$hcloud_token" ]]; then
        echo >&2 "Error: HCLOUD_TOKEN is required."
        exit 1
    fi
    export HCLOUD_TOKEN="$hcloud_token"
fi

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Change to the script's directory to ensure packer finds the files
cd "$SCRIPT_DIR"

echo "Initializing Packer..."
packer init .

# Function to get schematic ID from a schematic YAML file
get_schematic_id() {
    local schematic_file="$1"
    if [[ ! -f "$schematic_file" ]]; then
        echo >&2 "Error: Schematic file not found: $schematic_file"
        return 1
    fi

    local response
    response=$(curl -s -X POST --data-binary "@$schematic_file" https://factory.talos.dev/schematics)
    local schematic_id
    schematic_id=$(echo "$response" | jq -r '.id')

    if [[ -z "$schematic_id" || "$schematic_id" == "null" ]]; then
        echo >&2 "Error: Failed to get schematic ID from factory.talos.dev"
        echo >&2 "Response: $response"
        return 1
    fi

    echo "$schematic_id"
}

# Function to build images for a specific role
build_role() {
    local role="$1"
    local schematic_file="schematic-${role}.yaml"

    echo ""
    echo "=========================================="
    echo "Building images for role: ${role}"
    echo "=========================================="

    if [[ ! -f "$schematic_file" ]]; then
        echo >&2 "Error: Schematic file not found: $schematic_file"
        echo >&2 "Expected file at: ${SCRIPT_DIR}/${schematic_file}"
        exit 1
    fi

    echo "Getting schematic ID for ${role} from factory.talos.dev..."
    local schematic_id
    schematic_id=$(get_schematic_id "$schematic_file")
    echo "Schematic ID: ${schematic_id}"

    # Read talos_version: first from hcloud.auto.pkrvars.hcl, then from talos-hcloud.pkr.hcl default
    local talos_version=""
    if [[ -f "hcloud.auto.pkrvars.hcl" ]]; then
        talos_version=$(grep -E '^talos_version\s*=' hcloud.auto.pkrvars.hcl | sed 's/.*=\s*"\(.*\)".*/\1/' || true)
    fi
    if [[ -z "$talos_version" && -f "talos-hcloud.pkr.hcl" ]]; then
        # Extract default value from the Packer file
        talos_version=$(grep -A2 'variable "talos_version"' talos-hcloud.pkr.hcl | grep 'default' | sed 's/.*=\s*"\(.*\)".*/\1/' || true)
    fi
    if [[ -z "$talos_version" ]]; then
        echo >&2 "Error: Could not determine talos_version. Set it in hcloud.auto.pkrvars.hcl or talos-hcloud.pkr.hcl"
        exit 1
    fi

    local image_url_arm="https://factory.talos.dev/image/${schematic_id}/${talos_version}/hcloud-arm64.raw.xz"
    local image_url_x86="https://factory.talos.dev/image/${schematic_id}/${talos_version}/hcloud-amd64.raw.xz"

    echo "Talos version: ${talos_version}"
    echo "ARM image URL: ${image_url_arm}"
    echo "x86 image URL: ${image_url_x86}"
    echo ""

    packer build \
        -var "role=${role}" \
        -var "image_url_arm=${image_url_arm}" \
        -var "image_url_x86=${image_url_x86}" \
        .

    echo "Build complete for role: ${role}"
}

# Main logic
case "${1:-}" in
    --roles)
        # Build both control-plane and worker images
        build_role "control-plane"
        build_role "worker"
        echo ""
        echo "All role-specific builds completed successfully."
        ;;
    control-plane|worker)
        # Build images for a specific role
        build_role "$1"
        ;;
    "")
        # Default: build generic images without role label
        echo "Running packer build for generic images (no role label)..."
        echo "Tip: Use './create.sh --roles' to build role-specific images for control-plane and worker nodes."
        echo ""
        packer build .
        echo "Packer build finished successfully."
        ;;
    *)
        echo >&2 "Error: Unknown argument: $1"
        echo >&2 "Usage:"
        echo >&2 "  ./create.sh              # Build generic images (no role label)"
        echo >&2 "  ./create.sh --roles      # Build role-specific images (control-plane and worker)"
        echo >&2 "  ./create.sh control-plane # Build only control-plane images"
        echo >&2 "  ./create.sh worker        # Build only worker images"
        exit 1
        ;;
esac
