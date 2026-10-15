"""Exports the environment variables a package references to the following workflow steps.

Reads the names from the package's metadata/env-references.json and takes each value from the secret the workflow
passes as PACKAGE_SECRET_<NAME>, else from the Environment's variables, else the empty string; the package's
preflight.sh then refuses missing or empty values. Values are written only to $GITHUB_ENV, in the delimiter form that
keeps multiline values intact, and never printed.

Usage: export-environment.py <package_dir>; VARS_JSON holds toJSON(vars).
"""

import json
import os
import secrets
import sys

SECRET_PREFIX = "PACKAGE_SECRET_"


def main() -> None:
    package_dir = sys.argv[1]
    with open(os.path.join(package_dir, "metadata", "env-references.json"), encoding="utf-8") as file:
        references = json.load(file)
    environment_variables = json.loads(os.environ.get("VARS_JSON") or "{}")

    names = list(dict.fromkeys(reference["envVar"] for reference in references))
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as github_env:
        for name in names:
            value = os.environ.get(SECRET_PREFIX + name) or environment_variables.get(name) or ""
            delimiter = "EOF_" + secrets.token_hex(16)
            while delimiter in value:
                delimiter = "EOF_" + secrets.token_hex(16)
            github_env.write(f"{name}<<{delimiter}\n{value}\n{delimiter}\n")
    print(f"Exported {len(names)} package variables: {' '.join(names)}")


if __name__ == "__main__":
    main()
