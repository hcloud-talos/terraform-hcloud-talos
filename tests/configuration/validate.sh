#!/usr/bin/env bash
set -euo pipefail

config=$(mktemp)
trap 'rm -f "$config"' EXIT
printf '%s\n' "$TALOS_TEST_CONFIG" > "$config"
talosctl validate --config "$config" --mode cloud
