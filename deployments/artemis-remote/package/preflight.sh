#!/usr/bin/env bash
# Preflight for the generated remote-ansible package: the environment gate, static checks, and a
# syntax check only. This script never connects to a host and never applies changes.
set -euo pipefail
cd "$(dirname "$0")"

# Every environment variable the generated values reference; see metadata/env-references.json.
required_environment_variables="
ARTEMIS_DATABASE_PASSWORD
ARTEMIS_EMAIL_TEST
ARTEMIS_INTERNAL_ADMIN_PASSWORD
ARTEMIS_JHIPSTER_JWT
ARTEMIS_OPERATOR_ADMIN_NAME
ARTEMIS_OPERATOR_NAME
PROXY_SSL_CERTIFICATE_KEY_PATH
PROXY_SSL_CERTIFICATE_PATH
SERVER_HOSTNAME
TESTSERVER_NAME
"

echo "Checking required environment variables..."
missing=0
for name in ${required_environment_variables}; do
    if [ -z "${!name:-}" ]; then
        echo "ERROR: required environment variable ${name} is not set or is empty." >&2
        missing=1
    fi
done
if [ "${missing}" -ne 0 ]; then
    echo "ERROR: export the values listed above before running the playbook (see README.md)." >&2
    exit 1
fi

echo "Checking the pinned collection is installed..."
if ! ansible-galaxy collection list 2>/dev/null | grep -q "ls1intum.artemis"; then
    echo "ERROR: the ls1intum.artemis collection is not installed. Run: ansible-galaxy collection install -r requirements.yml" >&2
    exit 1
fi

echo "Running the playbook syntax check..."
ansible-playbook --syntax-check -i inventory/hosts playbook.yml

echo "Preflight passed. The package is consumable; deployment remains an admin action."
