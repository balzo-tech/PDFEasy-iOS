"""Minimal App Store Connect client for this repo's key (fastlane/.env)."""
import json, os, time, urllib.request, urllib.parse, urllib.error
import jwt

ROOT = "/Users/giuslape/Development/Balzo/PdfPro/PDFEasy-iOS"

def env():
    values = {}
    with open(os.path.join(ROOT, "fastlane/.env")) as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values

def token():
    e = env()
    path = e["ASC_KEY_FILEPATH"]
    if not os.path.isabs(path):
        path = os.path.join(ROOT, "fastlane", os.path.basename(path))
    with open(path) as handle:
        secret = handle.read()
    now = int(time.time())
    return jwt.encode({"iss": e["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200,
                       "aud": "appstoreconnect-v1"},
                      secret, algorithm="ES256", headers={"kid": e["ASC_KEY_ID"], "typ": "JWT"})

BASE = "https://api.appstoreconnect.apple.com/v1/"

def call(path, method="GET", body=None, params=None):
    # A full URL passes through: a couple of endpoints (availability, and every
    # "next page" link) live on /v2 or come back already spelt out.
    url = path if path.startswith("http") else BASE + path
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    request.add_header("Authorization", "Bearer " + token())
    if data:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode()
        raise SystemExit(f"{error.code} {method} {url}\n{detail}")


def upload_part(operation, chunk):
    """One slice of an asset, sent where App Store Connect asked for it."""
    request = urllib.request.Request(operation["url"], data=chunk,
                                     method=operation.get("method", "PUT"))
    for header in operation.get("requestHeaders", []):
        request.add_header(header["name"], header["value"])
    try:
        with urllib.request.urlopen(request) as response:
            return response.status
    except urllib.error.HTTPError as error:
        raise SystemExit(f"{error.code} upload: {error.read().decode()[:500]}")
