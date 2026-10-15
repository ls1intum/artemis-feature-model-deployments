"""Lists the values that are empty in this run, with their descriptions, in the run summary and the step log.

Runs after a failed preflight or SSH setup. It covers the connection values this repository's workflow needs and the
package variables listed in the package's metadata/env-references.json. Each row says whether the value belongs in
the target's GitHub Environment as a secret or as a variable.

Usage: missing-variables-summary.py <package_dir> <environment_name>
"""

import json
import os
import sys

CONNECTION_VALUES = [
    ("VM_HOST", "variable", "Host name or address of the VM, as the runner or the jump host reaches it."),
    ("VM_USERNAME", "variable", "User on the VM that runs the deployment."),
    ("VM_SSH_PRIVATE_KEY", "secret", "Private SSH key of that user."),
    ("SSH_KNOWN_HOSTS", "variable", "Host keys of the VM and of the jump host; run Check connection in scan mode to get them."),
]
GATEWAY_KEY = ("DEPLOYMENT_GATEWAY_SSH_KEY", "secret", "Private SSH key for the jump host named by DEPLOYMENT_GATEWAY_HOST.")


def main() -> None:
    package_dir, environment_name = sys.argv[1], sys.argv[2]
    with open(os.path.join(package_dir, "metadata", "env-references.json"), encoding="utf-8") as file:
        references = json.load(file)

    rows = []
    listed = set()
    connection_values = list(CONNECTION_VALUES)
    if os.environ.get("DEPLOYMENT_GATEWAY_HOST"):
        connection_values.append(GATEWAY_KEY)
    for name, kind, description in connection_values:
        if not os.environ.get(name):
            listed.add(name)
            rows.append(f"| `{name}` | Environment {kind} | {description} |")
    for reference in references:
        name = reference["envVar"]
        if name in listed or os.environ.get(name):
            continue
        listed.add(name)
        place = "Environment secret" if reference.get("kind") == "secret" else "Environment variable"
        description = reference.get("description", "").replace("|", "\\|")
        rows.append(f"| `{name}` | {place} | {description} |")

    lines = ["## Missing deployment values", ""]
    if rows:
        lines += [
            f"Add these values to the GitHub Environment `{environment_name}`, then re-run this workflow.",
            "",
            "| Variable | Set on GitHub as | Description |",
            "|---|---|---|",
            *rows,
        ]
    else:
        lines.append("Every value has been set; the run failed for another reason, see the failed step's log.")
    report = "\n".join(lines) + "\n"
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        summary.write(report)
    print(report, end="")


if __name__ == "__main__":
    main()
