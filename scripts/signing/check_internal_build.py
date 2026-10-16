"""Checks, after an [interne] upload, that App Store Connect really classed the build « Internal Only ».

The [interne] build has Premium unlocked: it must never reach the App Store or external testers. The export
option testFlightInternalTestingOnly asks for that, and this script verifies it with the App Store Connect
API (the CI's existing key). If the build is App Store eligible, it is expired at once and the job fails.

    python3 scripts/signing/check_internal_build.py KEY.p8 KEY_ID ISSUER_ID BUNDLE_ID BUILD_NUMBER

Standard library only (+ openssl for the ES256 signature). Exit codes: 0 internal only, 1 eligible (expired),
2 not found in time (to check by hand in TestFlight).
"""
import base64
import json
import subprocess
import sys
import time
import urllib.parse
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(signature):
    """openssl gives an ECDSA signature in DER (SEQUENCE of two INTEGERs); a JWT wants r || s, 32 bytes each."""
    assert signature[0] == 0x30
    index = 2 if signature[1] < 0x80 else 2 + (signature[1] & 0x7F)
    parts = []
    for _ in range(2):
        assert signature[index] == 0x02
        length = signature[index + 1]
        value = signature[index + 2:index + 2 + length].lstrip(b"\x00")
        parts.append(value.rjust(32, b"\x00"))
        index += 2 + length
    return parts[0] + parts[1]


def token(key_path, key_id, issuer):
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    now = int(time.time())
    payload = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}).encode())
    message = f"{header}.{payload}".encode()
    signature = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=message, capture_output=True, check=True).stdout
    return f"{header}.{payload}.{b64url(der_to_raw(signature))}"


def call(method, path, jwt, body=None):
    request = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body else None)
    request.add_header("Authorization", f"Bearer {jwt}")
    request.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read() or b"{}")


def main():
    key_path, key_id, issuer, bundle_id, build_number = sys.argv[1:6]
    jwt = token(key_path, key_id, issuer)
    apps = call("GET", "/apps?" + urllib.parse.urlencode({"filter[bundleId]": bundle_id}), jwt)["data"]
    if not apps:
        print(f"internal check: app {bundle_id} not found")
        return 2
    app_id = apps[0]["id"]
    query = urllib.parse.urlencode({"filter[app]": app_id, "filter[version]": build_number,
                                    "fields[builds]": "version,buildAudienceType,processingState,expired"})
    deadline = time.time() + 25 * 60
    while time.time() < deadline:
        jwt = token(key_path, key_id, issuer)
        builds = call("GET", "/builds?" + query, jwt)["data"]
        if builds:
            build = builds[0]
            audience = build["attributes"].get("buildAudienceType")
            if audience == "INTERNAL_ONLY":
                print(f"internal check: build {build_number} is Internal Only")
                return 0
            if audience:
                call("PATCH", f"/builds/{build['id']}", jwt,
                     {"data": {"type": "builds", "id": build["id"], "attributes": {"expired": True}}})
                print(f"internal check: build {build_number} was {audience}, now expired")
                return 1
        time.sleep(30)
    print(f"internal check: build {build_number} not visible after 25 min, check the « Internal » label in TestFlight")
    return 2


if __name__ == "__main__":
    sys.exit(main())
