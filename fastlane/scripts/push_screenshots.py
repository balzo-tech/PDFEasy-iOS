"""The Dutch slides, onto the version that is open for editing.

They were shot on 2026-09-10 and never went up: `fastlane metadata` cannot carry
screenshots by design (the Deliverfile keeps `skip_screenshots(true)` so an
unattended text upload can never hand a language ten more slides), and the lane
that could is blocked by the same app-info freeze as everything else deliver
touches. So the Dutch store page has been showing the English pictures.

Uploading is three steps per file — reserve, send, confirm — and the checksum is
required here, unlike the event pictures.
"""
import hashlib, os, sys
from PIL import Image
import asc

APP = "1659625843"
# 1284 x 2778 is the 6.5" slot, which is the one the other languages use.
DISPLAY_TYPE = "APP_IPHONE_65"


def version_localization(version_string: str, locale: str) -> str:
    version = asc.call(f"apps/{APP}/appStoreVersions",
                       params={"filter[versionString]": version_string,
                               "filter[platform]": "IOS"})["data"][0]["id"]
    for row in asc.call(f"appStoreVersions/{version}/appStoreVersionLocalizations",
                        params={"limit": 50})["data"]:
        if row["attributes"]["locale"] == locale:
            return row["id"]
    raise SystemExit(f"no {locale} localization on {version_string}")


def screenshot_set(localization_id: str) -> str:
    for row in asc.call(f"appStoreVersionLocalizations/{localization_id}/appScreenshotSets",
                        params={"limit": 20})["data"]:
        if row["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE:
            return row["id"]
    created = asc.call("appScreenshotSets", method="POST", body={"data": {
        "type": "appScreenshotSets",
        "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
        "relationships": {"appStoreVersionLocalization": {
            "data": {"type": "appStoreVersionLocalizations", "id": localization_id}}}}})
    return created["data"]["id"]


def upload(set_id: str, path: str) -> None:
    with open(path, "rb") as handle:
        data = handle.read()
    created = asc.call("appScreenshots", method="POST", body={"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {
            "data": {"type": "appScreenshotSets", "id": set_id}}}}})
    asset_id = created["data"]["id"]
    for operation in created["data"]["attributes"]["uploadOperations"]:
        offset, length = operation["offset"], operation["length"]
        asc.upload_part(operation, data[offset:offset + length])
    asc.call(f"appScreenshots/{asset_id}", method="PATCH", body={"data": {
        "type": "appScreenshots", "id": asset_id,
        "attributes": {"uploaded": True,
                       "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


def main(version_string: str, locale: str, folder: str) -> None:
    localization_id = version_localization(version_string, locale)
    set_id = screenshot_set(localization_id)
    already = asc.call(f"appScreenshotSets/{set_id}/appScreenshots",
                       params={"limit": 20})["data"]
    if already:
        print(f"{locale} already has {len(already)} slides in {DISPLAY_TYPE}; leaving them alone")
        return
    files = sorted(f for f in os.listdir(folder) if f.startswith("iphone") and f.endswith(".png"))
    for name in files:
        path = os.path.join(folder, name)
        width, height = Image.open(path).size
        if (width, height) != (1284, 2778):
            raise SystemExit(f"{name} is {width}x{height}, not a 6.5\" slide")
        upload(set_id, path)
        print(f"  {name} up")
    print(f"{locale}: {len(files)} slides on {version_string}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
