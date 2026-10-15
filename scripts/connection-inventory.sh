#!/usr/bin/env bash
# Writes the connection inventory of a target: its package's target group with one host that reaches the VM through
# the `artemis-vm` SSH alias. The group is read with Ansible's own parser: the single child group of `artemistests`
# in the package's inventory/hosts.
#
# Usage: connection-inventory.sh <package_dir> <target> <output_file>
set -euo pipefail

package_dir=$1 target=$2 output=$3
groups=$(ansible-inventory -i "$package_dir/inventory/hosts" --list | jq -r '.artemistests.children // [] | .[]')
if [ "$(grep -c . <<<"$groups" || true)" -ne 1 ]; then
  echo "::error::expected exactly one child group of artemistests in $package_dir/inventory/hosts, found: $(tr '\n' ' ' <<<"$groups")"
  exit 1
fi
printf '[%s]\n%s ansible_host=artemis-vm\n' "$groups" "$target" > "$output"
echo "connection inventory: group $groups, host $target"
