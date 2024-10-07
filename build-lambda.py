#!/usr/bin/env python

"""
Builds package ZIP file with lambda function.

This script creates persistent ZIP file with removing all ephemeral metadata:
timestamps, modes, etc. After removal extra metadata ZIP file should have the
same checksum if the content stays the same.

Returns error if any command failed or ZIP file has been changed so it can
be used as a pre-commit hook.

Python code is used instead of bash to avoid using another linter.
"""

import hashlib
import os
import shutil
import subprocess
from pathlib import Path


def run_command(command: str) -> None:
    result = subprocess.run(command, shell=True, check=True, text=True)
    if result.returncode != 0:
        raise SystemExit("Command failed")


script_dir = Path(__file__).resolve().parent
os.chdir(script_dir)

try:
    with open("package.zip", "rb") as file_to_check:
        data = file_to_check.read()
        old_checksum = hashlib.sha256(data).hexdigest()
except FileNotFoundError:
    old_checksum = None

run_command("poetry install")
run_command("poetry self add poetry-plugin-lambda-build")
run_command("poetry build-lambda --no-checksum package-artifact-path=package")
run_command("find . -print0 | xargs -0 touch -t 202001010000")
run_command(
    "cd package && zip -0 -FS -r -x '*.dist-info/*' -x '*/__pycache__/*' -x '*/__main__.py' -X ../package.zip *"
)
shutil.rmtree("package")

with open("package.zip", "rb") as file_to_check:
    data = file_to_check.read()
    new_checksum = hashlib.sha256(data).hexdigest()

if os.environ.get("PRE_COMMIT") and new_checksum != old_checksum:
    raise SystemExit("Archive is changed")
