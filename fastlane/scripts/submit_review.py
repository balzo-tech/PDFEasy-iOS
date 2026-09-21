"""Sends a version to App Review, with whatever else has to go with it.

    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/submit_review.py 1.35
    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/submit_review.py 1.35 --dry-run

Three calls, in this order, and none of them is what fastlane does:

    POST reviewSubmissions          open a submission for the platform
    POST reviewSubmissionItems      put the version in it — and anything else
    PATCH reviewSubmissions/{id}    submitted: true

**The second call is the reason this script exists.** A new in-app purchase is
reviewed with the version that introduces it and has to be added to the
submission as an item of its own: left out, the build ships and the product
stays in `READY_TO_SUBMIT` for ever, which on this app means the paywall quietly
falls back to the plans it already had. Every purchase that is waiting — state
`READY_TO_SUBMIT` — is picked up automatically, so nobody has to remember.

⚠️ Dates from this API are in Pacific time even though they end in `Z`. Nothing
here depends on one, and that is deliberate.
"""
import sys

import asc

BUNDLE_ID = "eu.balzo.pdfexpert"
PLATFORM = "IOS"


def app_id():
    return asc.call("apps", params={"filter[bundleId]": BUNDLE_ID})["data"][0]["id"]


def version(app, number):
    versions = asc.call(f"apps/{app}/appStoreVersions",
                        params={"limit": 20, "filter[platform]": PLATFORM,
                                "fields[appStoreVersions]": "versionString,appStoreState"})
    for row in versions["data"]:
        if row["attributes"]["versionString"] == number:
            return row["id"], row["attributes"]["appStoreState"]
    raise SystemExit(f"la versione {number} non esiste su App Store Connect")


def waiting_purchases(app):
    """The in-app purchases that are ready but have never been through review."""
    out = asc.call(f"apps/{app}/inAppPurchasesV2",
                   params={"limit": 50, "fields[inAppPurchases]": "productId,state"})
    return [(row["id"], row["attributes"]["productId"])
            for row in out.get("data", [])
            if row["attributes"]["state"] == "READY_TO_SUBMIT"]


def open_submission(app):
    """The submission in progress, or a new one."""
    existing = asc.call(f"apps/{app}/reviewSubmissions",
                        params={"limit": 10, "filter[state]": "READY_FOR_REVIEW",
                                "filter[platform]": PLATFORM})
    if existing.get("data"):
        return existing["data"][0]["id"]
    created = asc.call("reviewSubmissions", method="POST", body={
        "data": {"type": "reviewSubmissions",
                 "attributes": {"platform": PLATFORM},
                 "relationships": {"app": {"data": {"type": "apps", "id": app}}}}})
    return created["data"]["id"]


def add(submission, kind, identifier):
    body = {"data": {"type": "reviewSubmissionItems",
                     "relationships": {
                         "reviewSubmission": {"data": {"type": "reviewSubmissions",
                                                       "id": submission}},
                         kind: {"data": {"type": ("appStoreVersions" if kind == "appStoreVersion"
                                                  else "inAppPurchases"),
                                         "id": identifier}}}}}
    return asc.call("reviewSubmissionItems", method="POST", body=body)["data"]["id"]


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    number = argv[1]
    dry_run = "--dry-run" in argv

    app = app_id()
    version_id, state = version(app, number)
    purchases = waiting_purchases(app)

    print(f"app {app} · versione {number} ({version_id}) in stato {state}")
    for _, product in purchases:
        print(f"  acquisto da mandare in review insieme: {product}")
    if dry_run:
        print("--dry-run: non è stato inviato niente")
        return

    submission = open_submission(app)
    print("submission", submission)
    print("  versione aggiunta:", add(submission, "appStoreVersion", version_id))
    for purchase_id, product in purchases:
        print(f"  {product} aggiunto:", add(submission, "inAppPurchaseV2", purchase_id))

    asc.call(f"reviewSubmissions/{submission}", method="PATCH", body={
        "data": {"type": "reviewSubmissions", "id": submission,
                 "attributes": {"submitted": True}}})
    print("inviata in revisione")


if __name__ == "__main__":
    main(sys.argv)
