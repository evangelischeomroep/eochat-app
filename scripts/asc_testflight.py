#!/usr/bin/env python3
"""
asc_testflight.py — App Store Connect API: poll Xcode Cloud builds, add to TestFlight group,
                    and submit new App Store versions for review.

Usage:
  # Discover CI product ID and AI-team group ID (run once to verify setup):
  python3 scripts/asc_testflight.py --discover

  # Wait for Xcode Cloud build for a given app version to succeed, then add to AI-team:
  python3 scripts/asc_testflight.py --version 3.4.2

  # Add to AI-team without waiting (build must already exist):
  python3 scripts/asc_testflight.py --version 3.4.2 --no-wait

  # Submit a new App Store version for review (fully via CLI, no browser needed):
  python3 scripts/asc_testflight.py --submit-for-review \\
      --app-store-version 1.2 \\
      --build-version 3.4.2 \\
      --whats-new "Bug fixes and performance improvements." \\
      --locale nl-NL

  # Same but specifying the build ID directly (from --list-builds):
  python3 scripts/asc_testflight.py --submit-for-review \\
      --app-store-version 1.2 \\
      --build-id <build-uuid> \\
      --whats-new "Bug fixes and performance improvements."

Requirements:
  None — uses only Python stdlib + the openssl binary (always present on macOS)
"""

import argparse
import base64
import json
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib import request as urllib_request, error as urllib_error

# ---------------------------------------------------------------------------
# Config — all non-secret; the only secret is the .p8 file on disk
# ---------------------------------------------------------------------------
APP_ID          = "6763726069"
KEY_ID          = "8S2MXC2RH7"
ISSUER_ID       = "69a6de79-b43b-47e3-e053-5b8c7c11a4d1"
P8_PATH         = Path(__file__).parent / f"AuthKey_{KEY_ID}.p8"
BASE_URL        = "https://api.appstoreconnect.apple.com/v1"
GROUP_NAME      = "AI-team"
CI_PRODUCT_ID   = "60947880-F680-490A-BA80-9230D5768E95"
AI_TEAM_GROUP_ID = "df2bf483-c7df-41d6-b4df-edcecbaf38c9"

POLL_INTERVAL = 30   # seconds between status checks
POLL_TIMEOUT  = 2400 # 40 minutes max wait


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _der_to_raw64(der: bytes) -> bytes:
    """Convert DER ECDSA signature (SEQUENCE { INTEGER r, INTEGER s }) to raw 64-byte r||s."""
    # 30 <seq_len> 02 <r_len> <r_bytes> 02 <s_len> <s_bytes>
    assert der[0] == 0x30, "expected DER SEQUENCE"
    idx = 2  # skip 0x30 + length byte
    assert der[idx] == 0x02
    r = der[idx + 2: idx + 2 + der[idx + 1]]
    idx += 2 + der[idx + 1]
    assert der[idx] == 0x02
    s = der[idx + 2: idx + 2 + der[idx + 1]]
    # strip leading 0x00 padding, then left-pad to 32 bytes
    return r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00")


def _make_token() -> str:
    now = int(time.time())
    header  = _b64url(json.dumps({"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}, separators=(",", ":")).encode())
    payload = _b64url(json.dumps({"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode())
    signing_input = f"{header}.{payload}".encode()
    result = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", str(P8_PATH)],
        input=signing_input, capture_output=True, check=True,
    )
    raw_sig = _der_to_raw64(result.stdout)
    return f"{header}.{payload}.{_b64url(raw_sig)}"


def _request(method: str, path: str, body: dict | None = None) -> dict:
    url = path if path.startswith("http") else f"{BASE_URL}{path}"
    token = _make_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    data = json.dumps(body).encode() if body else None
    req = urllib_request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib_request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib_error.HTTPError as e:
        body_text = e.read().decode()
        print(f"HTTP {e.code} on {method} {url}: {body_text}", file=sys.stderr)
        raise


def get(path: str) -> dict:
    return _request("GET", path)


def post(path: str, body: dict) -> dict:
    return _request("POST", path, body)


def patch(path: str, body: dict) -> dict:
    return _request("PATCH", path, body)


# ---------------------------------------------------------------------------
# App Store Connect helpers
# ---------------------------------------------------------------------------
def get_ci_product_id() -> str:
    """Return the Xcode Cloud ciProduct ID for the app."""
    data = get(f"/apps/{APP_ID}/ciProduct")
    return data["data"]["id"]


def get_ai_team_group_id() -> str:
    """Return the TestFlight betaGroup ID for GROUP_NAME."""
    data = get(f"/apps/{APP_ID}/betaGroups")
    for group in data["data"]:
        if group["attributes"]["name"] == GROUP_NAME:
            return group["id"]
    names = [g["attributes"]["name"] for g in data["data"]]
    raise RuntimeError(f"Group '{GROUP_NAME}' not found. Available groups: {names}")


def get_latest_build_run(ci_product_id: str, version: str) -> dict | None:
    """Return the most recent build run (sort=-number is the valid ASC sort field)."""
    data = get(f"/ciProducts/{ci_product_id}/buildRuns?sort=-number&limit=10")
    if data["data"]:
        return data["data"][0]
    return None


def get_build_run_failure_reason(build_run_id: str) -> str:
    """Fetch the first failed action's issue summary for a failed build run."""
    try:
        actions = get(f"/ciBuildRuns/{build_run_id}/actions")
        for action in actions.get("data", []):
            a = action["attributes"]
            if a.get("completionStatus") in ("FAILED", "ERRORED"):
                return f"Action '{a.get('name','?')}' failed: {a.get('issueSummaries', '')}"
        return "No failed actions found in run."
    except Exception as e:
        return f"Could not fetch actions: {e}"


def wait_for_build_run(ci_product_id: str, version: str) -> dict:
    """Poll until a build run for the given version completes successfully."""
    print(f"Waiting for Xcode Cloud build for v{version}…")
    deadline = time.time() + POLL_TIMEOUT
    seen_id = None

    while time.time() < deadline:
        run = get_latest_build_run(ci_product_id, version)
        if run is None:
            print("  No build run found yet, waiting…")
            time.sleep(POLL_INTERVAL)
            continue

        run_id = run["id"]
        attrs = run["attributes"]
        status = attrs.get("executionProgress", "UNKNOWN")
        completed = attrs.get("completionStatus")

        if run_id != seen_id:
            seen_id = run_id
            started = attrs.get("startedDate", "?")
            print(f"  Build run {run_id} started {started}")

        print(f"  [{datetime.now(timezone.utc).strftime('%H:%M:%S')}] status={status} completion={completed}")

        if completed == "SUCCEEDED":
            print(f"  ✅ Build run succeeded.")
            return run
        elif completed in ("FAILED", "ERRORED", "CANCELED"):
            reason = get_build_run_failure_reason(run_id)
            raise RuntimeError(f"Xcode Cloud build {run_id} ended with {completed}.\n  {reason}")

        time.sleep(POLL_INTERVAL)

    raise TimeoutError(f"Xcode Cloud build did not complete within {POLL_TIMEOUT}s")


def get_app_store_build_from_run(build_run_id: str) -> str:
    """Return the App Store build ID linked to a CI build run."""
    data = get(f"/ciBuildRuns/{build_run_id}/builds")
    if not data["data"]:
        raise RuntimeError(f"No App Store builds linked to CI run {build_run_id} yet")
    return data["data"][0]["id"]


def get_build_id_by_version(version: str) -> str:
    """Find an App Store build ID by marketing version (e.g. '3.4.2')."""
    # 'version' in the builds API is the build number (CFBundleVersion), not the
    # marketing version. Marketing version lives in the preReleaseVersion relationship.
    data = get(
        f"/builds?filter[app]={APP_ID}"
        f"&filter[preReleaseVersion.version]={version}"
        f"&sort=-uploadedDate&limit=5"
    )
    if not data["data"]:
        raise RuntimeError(
            f"No builds found for marketing version {version}. "
            f"Run --list-builds to see available builds."
        )
    return data["data"][0]["id"]


def cmd_list_builds():
    """Print recent builds for diagnostic purposes."""
    data = get(
        f"/builds?filter[app]={APP_ID}"
        f"&include=preReleaseVersion"
        f"&sort=-uploadedDate&limit=10"
    )
    # Build a map from preReleaseVersion id → version string
    prv_map = {
        r["id"]: r["attributes"]["version"]
        for r in data.get("included", [])
        if r["type"] == "preReleaseVersions"
    }
    print(f"{'Marketing ver':<15} {'Build #':<10} {'State':<20} {'Uploaded':<26} ID")
    print("-" * 105)
    for b in data["data"]:
        a = b["attributes"]
        prv_id = (b.get("relationships", {}).get("preReleaseVersion", {})
                  .get("data", {}) or {}).get("id", "")
        mkt_ver = prv_map.get(prv_id, "?")
        print(f"{mkt_ver:<15} {a.get('version','?'):<10} "
              f"{a.get('processingState','?'):<20} {a.get('uploadedDate','?'):<26} {b['id']}")


def add_build_to_group(group_id: str, build_id: str) -> None:
    """Add a build to a TestFlight beta group."""
    body = {"data": [{"type": "builds", "id": build_id}]}
    try:
        post(f"/betaGroups/{group_id}/relationships/builds", body)
        print(f"  ✅ Build {build_id} added to group {GROUP_NAME}.")
    except urllib_error.HTTPError as e:
        if e.code == 409:
            print(f"  ℹ️  Build {build_id} already in group {GROUP_NAME} (409 conflict — OK).")
        else:
            raise


# ---------------------------------------------------------------------------
# App Store submission helpers
# ---------------------------------------------------------------------------
def create_app_store_version(version_string: str) -> str:
    """Create a new App Store version entry; return its ID."""
    body = {
        "data": {
            "type": "appStoreVersions",
            "attributes": {
                "platform": "IOS",
                "versionString": version_string,
                "releaseType": "AFTER_APPROVAL",
            },
            "relationships": {
                "app": {"data": {"type": "apps", "id": APP_ID}}
            },
        }
    }
    data = post("/appStoreVersions", body)
    version_id = data["data"]["id"]
    print(f"  Created App Store version {version_string} → id={version_id}")
    return version_id


def attach_build_to_asc_version(version_id: str, build_id: str) -> None:
    """Attach an App Store build to an App Store version."""
    body = {
        "data": {
            "type": "appStoreVersions",
            "id": version_id,
            "relationships": {
                "build": {"data": {"type": "builds", "id": build_id}}
            },
        }
    }
    patch(f"/appStoreVersions/{version_id}", body)
    print(f"  Attached build {build_id} to version {version_id}.")


def upsert_localization(version_id: str, locale: str, whats_new: str) -> None:
    """Set 'What's New' text for a given locale, creating the localization if needed."""
    data = get(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    existing = {r["attributes"]["locale"]: r["id"] for r in data.get("data", [])}

    if locale in existing:
        loc_id = existing[locale]
        body = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": loc_id,
                "attributes": {"whatsNew": whats_new},
            }
        }
        patch(f"/appStoreVersionLocalizations/{loc_id}", body)
        print(f"  Updated '{locale}' What's New text.")
    else:
        body = {
            "data": {
                "type": "appStoreVersionLocalizations",
                "attributes": {"locale": locale, "whatsNew": whats_new},
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    }
                },
            }
        }
        post("/appStoreVersionLocalizations", body)
        print(f"  Created '{locale}' localization with What's New text.")


def submit_version_for_review(version_id: str) -> None:
    """Submit an App Store version for App Review."""
    body = {
        "data": {
            "type": "appStoreVersionSubmissions",
            "relationships": {
                "appStoreVersion": {
                    "data": {"type": "appStoreVersions", "id": version_id}
                }
            },
        }
    }
    post("/appStoreVersionSubmissions", body)
    print("  ✅ Submitted for App Review.")


def cmd_submit_for_review(
    app_store_version: str,
    build_version: str | None,
    build_id: str | None,
    whats_new: str,
    locale: str,
) -> None:
    """End-to-end: create version → attach build → set What's New → submit."""
    if not P8_PATH.exists():
        print(f"❌ .p8 key not found at {P8_PATH}", file=sys.stderr)
        sys.exit(1)

    # Resolve build ID
    if build_id:
        resolved_build_id = build_id
        print(f"Using supplied build ID: {resolved_build_id}")
    elif build_version:
        print(f"Looking up latest build for marketing version {build_version}…")
        resolved_build_id = get_build_id_by_version(build_version)
        print(f"Found build: {resolved_build_id}")
    else:
        print("❌ Provide --build-version or --build-id.", file=sys.stderr)
        sys.exit(1)

    print(f"\nCreating App Store version {app_store_version}…")
    version_id = create_app_store_version(app_store_version)

    print(f"\nAttaching build…")
    attach_build_to_asc_version(version_id, resolved_build_id)

    print(f"\nSetting What's New ({locale})…")
    upsert_localization(version_id, locale, whats_new)

    print(f"\nSubmitting for review…")
    submit_version_for_review(version_id)

    print(f"\n✅ EOchat {app_store_version} submitted for App Store review.")
    print(f"   Apple will email when review is complete (typically < 24 h).")


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
def cmd_discover():
    print("Verifying App Store Connect API access…\n")
    try:
        ci_id = get_ci_product_id()
        print(f"CI Product ID : {ci_id}")
    except Exception as e:
        print(f"❌ Could not fetch CI product: {e}")
        sys.exit(1)

    try:
        group_id = get_ai_team_group_id()
        print(f"AI-team group ID: {group_id}")
    except Exception as e:
        print(f"❌ Could not fetch beta groups: {e}")
        sys.exit(1)

    print("\n✅ Setup looks good.")


def cmd_add_to_testflight(version: str, wait: bool):
    if not P8_PATH.exists():
        print(f"❌ .p8 key not found at {P8_PATH}", file=sys.stderr)
        sys.exit(1)

    ci_product_id = CI_PRODUCT_ID
    group_id = AI_TEAM_GROUP_ID
    print(f"CI product: {ci_product_id}  |  AI-team group: {group_id}")

    if wait:
        build_run = wait_for_build_run(ci_product_id, version)
        try:
            build_id = get_app_store_build_from_run(build_run["id"])
        except RuntimeError:
            # CI run exists but build link not yet propagated — fall back to version lookup
            print("  Build not linked to CI run yet, falling back to version lookup…")
            time.sleep(30)
            build_id = get_build_id_by_version(version)
    else:
        build_id = get_build_id_by_version(version)

    print(f"App Store build ID: {build_id}")
    add_build_to_group(group_id, build_id)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description="App Store Connect / TestFlight helper")

    # --- TestFlight / Xcode Cloud commands ---
    parser.add_argument("--discover", action="store_true", help="Verify setup and print IDs")
    parser.add_argument("--list-builds", action="store_true", help="List recent App Store builds (diagnostic)")
    parser.add_argument("--check-last-build", action="store_true", help="Show status and failure reason of most recent Xcode Cloud run")
    parser.add_argument("--version", help="App version string to add to TestFlight (e.g. 3.4.2)")
    parser.add_argument("--no-wait", action="store_true", help="Skip polling; add immediately")

    # --- App Store submission command ---
    parser.add_argument("--submit-for-review", action="store_true",
                        help="Create a new App Store version and submit for review")
    parser.add_argument("--app-store-version", metavar="VER",
                        help="App Store version string (e.g. 1.2) — required with --submit-for-review")
    parser.add_argument("--build-version", metavar="VER",
                        help="Marketing version of the build to attach (e.g. 3.4.2); "
                             "finds the latest matching build")
    parser.add_argument("--build-id", metavar="UUID",
                        help="App Store build UUID to attach (overrides --build-version)")
    parser.add_argument("--whats-new", metavar="TEXT",
                        help="Release notes for the App Store listing")
    parser.add_argument("--locale", metavar="LOCALE", default="nl-NL",
                        help="Locale for What's New text (default: nl-NL)")

    args = parser.parse_args()

    if args.discover:
        cmd_discover()
    elif args.list_builds:
        cmd_list_builds()
    elif args.check_last_build:
        run = get_latest_build_run(CI_PRODUCT_ID, "")
        if not run:
            print("No build runs found.")
        else:
            a = run["attributes"]
            print(f"Run #{a.get('number')}  status={a.get('executionProgress')}  completion={a.get('completionStatus')}")
            print(f"Started: {a.get('startedDate','?')}")
            if a.get("completionStatus") in ("FAILED", "ERRORED"):
                print(get_build_run_failure_reason(run["id"]))
    elif args.submit_for_review:
        if not args.app_store_version:
            parser.error("--submit-for-review requires --app-store-version")
        if not args.whats_new:
            parser.error("--submit-for-review requires --whats-new")
        if not args.build_version and not args.build_id:
            parser.error("--submit-for-review requires --build-version or --build-id")
        cmd_submit_for_review(
            app_store_version=args.app_store_version,
            build_version=args.build_version,
            build_id=args.build_id,
            whats_new=args.whats_new,
            locale=args.locale,
        )
    elif args.version:
        cmd_add_to_testflight(args.version, wait=not args.no_wait)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
