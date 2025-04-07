#!/bin/bash
# This script builds Hetzner Cloud images for Talos using Packer.

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

echo "Running packer build for talos-hcloud.pkr.hcl..."
# Build the packer image(s) defined in the current directory
packer build .

echo "Packer build finished successfully."
