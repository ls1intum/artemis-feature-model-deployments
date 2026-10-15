#!/usr/bin/env bash
# Writes the SSH configuration of the deploy and connection-check workflows: the alias `artemis-vm` for the target
# VM, reached directly or, when GATEWAY_HOST is set, through that jump host. Host keys are checked strictly against
# SSH_KNOWN_HOSTS unless CHECK_MODE=scan, which accepts and records new keys for an administrator to copy.
#
# Inputs (environment): VM_HOST, VM_USERNAME, VM_SSH_PRIVATE_KEY, SSH_KNOWN_HOSTS, optional GATEWAY_HOST,
# GATEWAY_PORT, GATEWAY_USER, GATEWAY_SSH_KEY, CHECK_MODE (strict by default), SSH_DIR (default ~/.ssh).
set -euo pipefail

fail() {
  echo "::error::$1"
  exit 1
}

ssh_dir=${SSH_DIR:-$HOME/.ssh}
check_mode=${CHECK_MODE:-strict}
[ -n "${VM_HOST:-}" ] || fail "the VM_HOST variable is not set in this Environment"
[ -n "${VM_USERNAME:-}" ] || fail "the VM_USERNAME variable is not set in this Environment"
[ -n "${VM_SSH_PRIVATE_KEY:-}" ] || fail "the VM_SSH_PRIVATE_KEY secret is not set in this Environment"

mkdir -p "$ssh_dir" && chmod 700 "$ssh_dir"
install -m 600 /dev/null "$ssh_dir/vm_key"
printf '%s\n' "$VM_SSH_PRIVATE_KEY" > "$ssh_dir/vm_key"
if [ "$check_mode" = scan ]; then
  : > "$ssh_dir/known_hosts"
  strict=accept-new
else
  [ -n "${SSH_KNOWN_HOSTS:-}" ] || fail "the SSH_KNOWN_HOSTS variable is not set in this Environment; run the connection check in scan mode to obtain it"
  printf '%s\n' "$SSH_KNOWN_HOSTS" > "$ssh_dir/known_hosts"
  strict=yes
fi

if [ -n "${GATEWAY_HOST:-}" ]; then
  [ -n "${GATEWAY_SSH_KEY:-}" ] || fail "DEPLOYMENT_GATEWAY_HOST is set but the DEPLOYMENT_GATEWAY_SSH_KEY secret is not"
  install -m 600 /dev/null "$ssh_dir/gateway_key"
  printf '%s\n' "$GATEWAY_SSH_KEY" > "$ssh_dir/gateway_key"
fi

{
  if [ -n "${GATEWAY_HOST:-}" ]; then
    echo "Host gateway"
    echo "  HostName $GATEWAY_HOST"
    [ -z "${GATEWAY_PORT:-}" ] || echo "  Port $GATEWAY_PORT"
    [ -z "${GATEWAY_USER:-}" ] || echo "  User $GATEWAY_USER"
    echo "  IdentityFile $ssh_dir/gateway_key"
  fi
  echo "Host artemis-vm"
  echo "  HostName $VM_HOST"
  echo "  User $VM_USERNAME"
  [ -z "${GATEWAY_HOST:-}" ] || echo "  ProxyJump gateway"
  echo "  IdentityFile $ssh_dir/vm_key"
  echo "Host *"
  echo "  IdentitiesOnly yes"
  echo "  StrictHostKeyChecking $strict"
  echo "  UserKnownHostsFile $ssh_dir/known_hosts"
  echo "  ServerAliveInterval 30"
} > "$ssh_dir/config"
chmod 600 "$ssh_dir/config"
echo "SSH config: artemis-vm ${GATEWAY_HOST:+through the jump host }with $check_mode host key checking"
