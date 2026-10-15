#!/usr/bin/env bash
# Resolves the target of a deploy run and checks its package against this repository's marker.
#
# A push names no target: it is the single deployments/<target>/ directory the push changed. A dispatch names it in
# its input. Writes target, package_dir, and deploy (true or false) to $GITHUB_OUTPUT; a push that removed the whole
# package directory of its target ends with deploy=false.
#
# Inputs (environment): GITHUB_EVENT_NAME, GITHUB_SHA, GITHUB_REF_NAME, GITHUB_OUTPUT, GITHUB_STEP_SUMMARY,
# TARGET_INPUT (dispatch), BEFORE (push: previous head of the branch, may be empty or all zeros).
set -euo pipefail

fail() {
  echo "::error::$1"
  exit 1
}

if [ "$GITHUB_EVENT_NAME" = workflow_dispatch ]; then
  target=$TARGET_INPUT
else
  base="$GITHUB_SHA^"
  if [ -n "${BEFORE:-}" ] && git cat-file -e "$BEFORE^{commit}" 2>/dev/null; then base=$BEFORE; fi
  changed=$(git diff --name-only "$base" "$GITHUB_SHA" -- deployments/ | cut -d/ -f2 | sort -u)
  if [ "$(grep -c . <<<"$changed" || true)" -ne 1 ]; then
    fail "expected exactly one changed target under deployments/, found: $(tr '\n' ' ' <<<"$changed")"
  fi
  target=$changed
fi

if ! [[ "$target" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]]; then
  fail "invalid target name '$target': use 1 to 63 lowercase letters, digits, or hyphens, starting with a letter or digit"
fi
package_dir="deployments/$target/package"
echo "target=$target" >> "$GITHUB_OUTPUT"
echo "package_dir=$package_dir" >> "$GITHUB_OUTPUT"

if [ "$GITHUB_EVENT_NAME" != workflow_dispatch ] && [ ! -e "$package_dir" ]; then
  echo "deploy=false" >> "$GITHUB_OUTPUT"
  echo "Target \`$target\`: the push removed its package, nothing to deploy." >> "$GITHUB_STEP_SUMMARY"
  exit 0
fi
if [ ! -f "$package_dir/playbook.yml" ]; then
  fail "no published package at $package_dir on ref $GITHUB_REF_NAME (dispatch on the deployment branch)"
fi

# The package contract: the package type and the major version this repository's workflow was written for.
update_hint="update the workflow and deployment-repository.json from the deployment template"
[ -f deployment-repository.json ] || fail "deployment-repository.json is missing; $update_hint"
contract=$(jq -r '.packageContract // empty' deployment-repository.json)
manifest="$package_dir/metadata/package-manifest.json"
[ -f "$manifest" ] || fail "$manifest is missing; the package is not a remote-ansible deployment package"
package_type=$(jq -r '.packageType // empty' "$manifest")
package_version=$(jq -r '.packageVersion // empty' "$manifest")
[ "$package_type" = remote-ansible-deployment-package ] \
  || fail "unexpected package type '$package_type' in $manifest; expected remote-ansible-deployment-package"
[ "${package_version%%.*}" = "$contract" ] \
  || fail "package version $package_version needs package contract ${package_version%%.*}, this repository declares $contract; $update_hint"

# deploy.yml passes package secrets by name; a package that needs a secret the workflow does not pass was published
# by a newer feature model release than this copy of the template knows.
references="$package_dir/metadata/env-references.json"
[ -f "$references" ] || fail "$references is missing; the package is not a remote-ansible deployment package"
passed=$(grep -oE 'PACKAGE_SECRET_[A-Z0-9_]+:' .github/workflows/deploy.yml | sed 's/^PACKAGE_SECRET_//; s/:$//' | sort -u)
needed=$(jq -r '.[] | select(.kind == "secret") | .envVar' "$references" | sort -u)
unknown=$(comm -23 <(echo "$needed") <(echo "$passed") | grep . || true)
[ -z "$unknown" ] || fail "the package needs secrets this workflow does not pass: $(paste -sd ' ' - <<<"$unknown"); $update_hint"

echo "deploy=true" >> "$GITHUB_OUTPUT"
