# Artemis Remote Deployment Package (Ansible)

Generated from feature model `artemis-generated-feature-model` version `0.1.0+3ef9968d9af6` and deployment context `default-artemis-profile`, with Ansible binding
catalog v2 curated against collection commit `fce6ad19a7ee58dbecc5632d5bb2b3f18f76886e`.

This package is **admin-consumable, not deployable**: it contains the complete values and
orchestration for deploying the selected Artemis variant with the pinned
`ls1intum.artemis` Ansible collection, but it holds no credentials and connects to nothing.
Deployment remains a deliberate admin action on an execution environment that provides SSH access
and the environment values.

## Contents

- `requirements.yml` — the Artemis collection pinned to the exact commit the values were curated against,
  plus the collections its roles need.
- `ansible.cfg` — minimal run semantics; `hash_behaviour = merge` is required by the inventory layering.
- `playbook.yml` — applies the collection's `artemis` and `legal` roles to the `artemistests` group.
- `inventory/` — group membership wiring and generated values for the selected variant.
- `preflight.sh` — the environment gate, static checks, and `ansible-playbook --syntax-check`; never
  connects to a host.
- `metadata/` — package manifest, layered readiness, every environment reference, and the selected features.

## Environment values

No environment value — identity or secret, dummy or real — is stored in this package. Every value is
referenced as a `lookup('ansible.builtin.env', …)` expression that Ansible resolves on the control
node at run time; `metadata/env-references.json` lists each variable with its consuming value and the
file referencing it. Provide the variables where the playbook runs:

- **Locally**: export the full set in the shell before running the preflight and the playbook.
- **GitHub Actions** (execution-plane stage): provision the same names as Actions secrets; the
  workflow injects them into the run environment.

Ownership of the values:

- **Identity values** (`TESTSERVER_NAME`, `SERVER_HOSTNAME`, `ARTEMIS_EMAIL_TEST`, the operator
  names, the certificate paths): admin-owned inputs describing the target environment.
- **Deployment-internal secrets**: both ends live inside this deployment, so self-generated random
  values are fully functional. Generate them once:

  ```bash
  export ARTEMIS_DATABASE_PASSWORD=$(openssl rand -base64 48)
  export ARTEMIS_INTERNAL_ADMIN_PASSWORD=$(openssl rand -base64 48)
  export ARTEMIS_JHIPSTER_JWT=$(openssl rand -base64 64 | tr -d '\n')
  ```

- **Integration secrets** (Iris, Athena, LTI, Sharing, Hyperion — when selected): these authenticate
  against an external service and must come from that service's operator.

**Keep the generated set stable.** Store the values once (for example as GitHub Actions secrets) and
reuse them for every deploy of the same target: a database applies its credentials only on first
initialization, so regenerating `ARTEMIS_DATABASE_PASSWORD` against an existing data volume locks
Artemis out with an access-denied loop instead of rotating the password.

Production note: a secret manager such as HashiCorp Vault stays compatible with this channel —
resolve the managed secrets into the environment of the run (or replace the generated lookup
expressions with your manager's lookup plugin). The package itself standardizes on plain environment
variables and requires no Vault server.

## Before running

1. Add your connection line to the empty target group in `inventory/hosts`, for example
   `<host> ansible_user=<user> ansible_ssh_private_key_file=<key>`.
2. Make sure the target host provides Docker, git, and the `acl` package — the collection installs none
   of them, and POSIX ACLs are needed wherever Ansible hands a file to the unprivileged artemis user.
3. Install the collections: `ansible-galaxy collection install -r requirements.yml`; the `ansible`
   meta-package already ships the non-Artemis collections. Add `ansible-galaxy role install
   geerlingguy.docker` if your target still needs Docker provisioned.
4. Export the environment values (previous section).
5. Run `./preflight.sh`. It fails fast on a missing or empty environment variable and on syntax
   problems.

## Deploying

```bash
./preflight.sh
ansible-playbook -i inventory/hosts playbook.yml
```

The deployed Artemis version is set by `artemis_version` in
`inventory/group_vars/artemistests_common_config.yml` (baseline: `develop`). Telemetry reporting is
disabled by default (`artemis_telemetry_enabled: false`); review the generated values before pointing
a deployment at any shared infrastructure.

## Lifecycle boundary

Generation proved: the selection is valid, every feature is classified against the binding catalog,
the values are generated, and environment values appear only as lookup expressions. It did **not**
prove the inventory renders or boots — that is the preflight's and the admin's job. See
`metadata/remote-readiness.json`.
