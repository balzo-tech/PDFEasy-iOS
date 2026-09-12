"""Write the per-version store texts straight to App Store Connect.

`fastlane metadata` cannot do this at the moment and the reason is not ours:
deliver asks for the **app info** — the name and subtitle, shared by every
platform — before it writes anything, and the app info is frozen while any
version of the app is in review. The Mac 1.28 has been in review since 20
August, so deliver retries "Cannot find edit app info" for ten minutes and then
fails, taking the description, keywords, release notes and promotional text with
it. None of those are app info; all of them belong to the version, which is
editable.

So they go up through the API that knows the difference. Nothing here can touch
the name, the subtitle, the screenshots or the build.
"""
import os, sys
import asc

APP = "1659625843"
ROOT = "/Users/giuslape/Development/Balzo/PdfPro/PDFEasy-iOS/fastlane/metadata"
FIELDS = {"description": "description", "keywords": "keywords",
          "release_notes": "whatsNew", "promotional_text": "promotionalText"}


def version(version_string: str) -> str:
    found = asc.call(f"apps/{APP}/appStoreVersions",
                     params={"filter[versionString]": version_string,
                             "filter[platform]": "IOS", "limit": 1})
    if found["data"]:
        state = found["data"][0]["attributes"]["appStoreState"]
        print(f"{version_string} already on App Store Connect ({state})")
        return found["data"][0]["id"]
    created = asc.call("appStoreVersions", method="POST", body={"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": version_string,
                       "releaseType": "MANUAL"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
    print(f"{version_string} created")
    return created["data"]["id"]


def texts(locale: str) -> dict:
    values = {}
    for filename, field in FIELDS.items():
        path = os.path.join(ROOT, locale, f"{filename}.txt")
        if os.path.exists(path):
            with open(path) as handle:
                values[field] = handle.read().strip()
    return values


def main(version_string: str) -> None:
    version_id = version(version_string)
    existing = {d["attributes"]["locale"]: d["id"] for d in
                asc.call(f"appStoreVersions/{version_id}/appStoreVersionLocalizations",
                         params={"limit": 50})["data"]}
    locales = sorted(d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d)))
    for locale in locales:
        values = texts(locale)
        if not values:
            print(f"{locale:8} nothing to write")
            continue
        if locale in existing:
            asc.call(f"appStoreVersionLocalizations/{existing[locale]}", method="PATCH",
                     body={"data": {"type": "appStoreVersionLocalizations",
                                    "id": existing[locale], "attributes": values}})
            print(f"{locale:8} updated  ({', '.join(sorted(values))})")
        else:
            body = {"data": {"type": "appStoreVersionLocalizations",
                             "attributes": {**values, "locale": locale},
                             "relationships": {"appStoreVersion": {
                                 "data": {"type": "appStoreVersions", "id": version_id}}}}}
            asc.call("appStoreVersionLocalizations", method="POST", body=body)
            print(f"{locale:8} created")


main(sys.argv[1] if len(sys.argv) > 1 else "1.32")
