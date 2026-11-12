"""Check an Android update, back up debug app data, then install with -r only.

Defaults to read-only checks. Never uninstalls, clears data or changes package ID.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone

PACKAGE = "dev.orbitwords.orbitwords"


def run(*args, binary=False, allow_failure=False):
    result = subprocess.run([str(a) for a in args], capture_output=True)
    if result.returncode and not allow_failure:
        raise RuntimeError(result.stderr.decode("utf-8", "replace") or result.stdout.decode("utf-8", "replace"))
    return result.stdout if binary else result.stdout.decode("utf-8", "replace").strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--serial", required=True, help="Exact adb device serial")
    parser.add_argument("--install", action="store_true", help="Install after checks and backup")
    parser.add_argument("--backup-dir", type=Path, help="Private local backup directory; required for an update")
    args = parser.parse_args()
    apk = args.apk.resolve(strict=True)
    sdk = args.sdk.resolve(strict=True)
    suffix = ".exe" if os.name == "nt" else ""
    adb = sdk / "platform-tools" / ("adb" + suffix)
    versions = [p for p in (sdk / "build-tools").iterdir() if re.fullmatch(r"\d+\.\d+\.\d+", p.name)]
    build_tools = max(versions, key=lambda p: tuple(map(int, p.name.split("."))))
    signer = build_tools / ("apksigner.bat" if os.name == "nt" else "apksigner")
    aapt = build_tools / ("aapt2" + suffix)

    def device(*command, **kw):
        return run(adb, "-s", args.serial, *command, **kw)

    def certificate(path):
        text = run(signer, "verify", "--print-certs", path)
        fingerprints = sorted(re.findall(r"Signer #\d+ certificate SHA-256 digest: ([a-fA-F0-9]+)", text))
        if not fingerprints:
            raise RuntimeError("No verified signing certificate found")
        return fingerprints

    def metadata(path):
        text = run(aapt, "dump", "badging", path)
        info = re.search(r"package: name='([^']+)' versionCode='(\d+)'", text)
        if not info or info[1] != PACKAGE:
            raise RuntimeError("Unexpected applicationId; refusing installation")
        return {"package": info[1], "versionCode": int(info[2])}

    if device("get-state") != "device":
        raise RuntimeError("The selected device is not ready")
    new = metadata(apk)
    new["certificateSha256"] = certificate(apk)
    new["apkSha256"] = hashlib.sha256(apk.read_bytes()).hexdigest()
    paths = device("shell", "pm", "path", PACKAGE, allow_failure=True)
    existing = next((line.removeprefix("package:") for line in paths.splitlines() if line.startswith("package:") and line.endswith("/base.apk")), None)
    if paths and not existing:
        raise RuntimeError("Cannot identify installed base APK; no changes made")
    with tempfile.TemporaryDirectory(prefix="kvesmos-apk-check-") as folder:
        old_apk = Path(folder) / "previous.apk"
        if existing:
            device("pull", existing, old_apk)
            old = metadata(old_apk)
            if certificate(old_apk) != new["certificateSha256"]:
                raise RuntimeError("SIGNATURE MISMATCH. Keep the installed app. Its original private signing key is required; uninstalling would delete local progress.")
            if new["versionCode"] < old["versionCode"]:
                raise RuntimeError("Version downgrade refused")
        print(json.dumps(new, indent=2))
        if not args.install:
            print("Checks passed. No data or installation changed.")
            return
        if existing:
            if not args.backup_dir:
                raise RuntimeError("--backup-dir is required before updating an installed app")
            destination = args.backup_dir.resolve() / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
            destination.mkdir(parents=True, exist_ok=False)
            # A stopped debug build permits a consistent snapshot of SQLite/WAL,
            # settings and files. A release build without run-as is not modified.
            roots = device("shell", "run-as", PACKAGE, "ls").splitlines()
            roots = [name for name in roots if name in {"files", "databases", "shared_prefs"}]
            if not roots:
                raise RuntimeError("Private data backup is unavailable; update refused")
            device("shell", "am", "force-stop", PACKAGE)
            archive = device("exec-out", "run-as", PACKAGE, "tar", "-cf", "-", *roots, binary=True)
            if len(archive) < 1024:
                raise RuntimeError("Incomplete data backup; update refused")
            (destination / "private-app-data.tar").write_bytes(archive)
            shutil.copy2(old_apk, destination / "previous.apk")
            (destination / "update.json").write_text(json.dumps({"previous": old, "next": new}, indent=2), encoding="utf-8")
            print("Private backup:", destination)
        output = device("install", "-r", apk)
        if "Success" not in output:
            raise RuntimeError(output or "Installation did not confirm success")
        print("Update installed with -r. Existing application data retained.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError) as error:
        raise SystemExit(str(error)) from None
