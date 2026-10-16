#!/usr/bin/env python3
"""Check Packer version validation without building an image."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


root = Path(__file__).resolve().parent.parent
matrix = json.loads((root / "supported_versions.json").read_text())
cases = [(None, True)]
for minor, support in matrix.items():
    minimum = support["minimum_patch"]
    cases.extend((f"v{minor}.{patch}", accepted) for patch, accepted in [
        (minimum - 1, False), (minimum, True), (minimum + 1, True), (100, True)
    ])
cases.extend((version, False) for version in [
    "v1.12.4", "v1.15.0", "v2.14.3", "v1.14.4-rc.1", "v1.14.3+custom",
    "1.14.3", "v1.14", "v1.14.03", "",
])

with tempfile.TemporaryDirectory() as directory:
    template = Path(directory) / "talos-hcloud.pkr.hcl"
    shutil.copyfile(root / "_packer/talos-hcloud.pkr.hcl", template)
    # Do not load the caller's credentials or auto variable files.
    environment = dict(os.environ, HCLOUD_TOKEN="test-token")
    subprocess.run(["packer", "init", str(template)], check=True, env=environment)
    for version, accepted in cases:
        command = ["packer", "validate"]
        if version is not None:
            command.append(f"-var=talos_version={version}")
        command.append(str(template))
        result = subprocess.run(command, capture_output=True, text=True, env=environment)
        if accepted != (result.returncode == 0):
            raise SystemExit(f"Unexpected result for {version or 'default'}:\n{result.stdout}{result.stderr}")
        if not accepted and "Unsupported talos_version" not in result.stdout + result.stderr:
            raise SystemExit(f"Wrong failure for {version}:\n{result.stdout}{result.stderr}")
        print(f"PASS: {version if version is not None else 'default'}")

print(f"Packer: {len(cases)} cases passed.")
