"""The in-app event for the meme maker, created as a draft.

An in-app event is a second card for the same app: it shows up in search
results, on the app's page and in the Today tab's event feed, with its own
picture, its own name and a badge. Two rows where there was one, which is the
whole reason for making it — the tool it advertises is a bet on being shared
rather than searched for, and this is the one surface where the store will show
it without anybody typing "meme".

Nothing here publishes: the event is created in draft, with its dates already
set, and a person submits it from App Store Connect when the version it talks
about is live.
"""
import os
import asc
from event_text import EVENT

APP = "1659625843"
REFERENCE_NAME = "Meme maker 1.32"
ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "event-art")

# Two weeks, opening four days after the build went up for review: the event and
# the version are two separate queues, and a card that promises a tool the live
# app does not have yet is the one way this gets turned down.
PUBLISH_START = "2026-09-16T22:00:00Z"   # midnight, 17 September, Rome
EVENT_START = "2026-09-16T22:00:00Z"
EVENT_END = "2026-09-30T22:00:00Z"

ASSETS = [("EVENT_CARD", "card"), ("EVENT_DETAILS_PAGE", "details")]


def territories() -> list[str]:
    """Everywhere the app is on sale.

    Availability moved to /v2 and answers with rows whose id is a base64 blob —
    `{"s": <app>, "t": <territory>}` — rather than with a relationship to the
    territory. Decoding the id is the documented way to read it back.
    """
    import base64, json
    url = f"https://api.appstoreconnect.apple.com/v2/appAvailabilities/{APP}/territoryAvailabilities"
    found, params = [], {"limit": 200}
    while url:
        page = asc.call(url, params=params)
        params = None
        for row in page["data"]:
            if not row["attributes"].get("available"):
                continue
            padded = row["id"] + "=" * (-len(row["id"]) % 4)
            found.append(json.loads(base64.b64decode(padded))["t"])
        url = page.get("links", {}).get("next")
    return sorted(found)


def create_event(where: list[str]) -> str:
    body = {"data": {
        "type": "appEvents",
        "attributes": {
            "referenceName": REFERENCE_NAME,
            "badge": "MAJOR_UPDATE",
            # The tool is free to use and the way out of it is not: saving and
            # sharing need the subscription, trial or not. Saying so here is
            # what keeps the review honest.
            "purchaseRequirement": "IN_APP_PURCHASE",
            "primaryLocale": "en-US",
            "priority": "HIGH",
            "purpose": "ATTRACT_NEW_USERS",
            # Straight into the tool: `Deeplink.tool(identifier:)` takes the
            # case name of `HomeAction`, and the catalog carries the meme maker
            # in every language even though the shortcut strip does not.
            "deepLink": "pdfpro://tool/memeMaker",
            "territorySchedules": [{"territories": where,
                                    "publishStart": PUBLISH_START,
                                    "eventStart": EVENT_START,
                                    "eventEnd": EVENT_END}],
        },
        "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}}
    return asc.call("appEvents", method="POST", body=body)["data"]["id"]


def localizations(event_id: str) -> dict[str, str]:
    return {d["attributes"]["locale"]: d["id"] for d in
            asc.call(f"appEvents/{event_id}/localizations", params={"limit": 50})["data"]}


def localize(event_id: str, locale: str) -> str:
    name, short, long_ = EVENT[locale]
    body = {"data": {
        "type": "appEventLocalizations",
        "attributes": {"locale": locale, "name": name,
                       "shortDescription": short, "longDescription": long_},
        "relationships": {"appEvent": {"data": {"type": "appEvents", "id": event_id}}}}}
    return asc.call("appEventLocalizations", method="POST", body=body)["data"]["id"]


def attach(localization_id: str, asset_type: str, path: str) -> None:
    """Puts one picture on one localisation, in the three steps the API wants:
    reserve, send the bytes, say it is done."""
    with open(path, "rb") as handle:
        data = handle.read()
    created = asc.call("appEventScreenshots", method="POST", body={"data": {
        "type": "appEventScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data),
                       "appEventAssetType": asset_type},
        "relationships": {"appEventLocalization": {
            "data": {"type": "appEventLocalizations", "id": localization_id}}}}})
    asset_id = created["data"]["id"]
    for operation in created["data"]["attributes"]["uploadOperations"]:
        offset, length = operation["offset"], operation["length"]
        asc.upload_part(operation, data[offset:offset + length])
    # Only `uploaded`: event screenshots take no checksum, unlike the store
    # screenshots the same three-step dance is used for elsewhere.
    asc.call(f"appEventScreenshots/{asset_id}", method="PATCH", body={"data": {
        "type": "appEventScreenshots", "id": asset_id,
        "attributes": {"uploaded": True}}})


def sync_pictures(localization_id: str, locale: str) -> str:
    """Whatever is missing or half-uploaded, again. Anything already delivered
    is left alone, so this can be re-run after a run that died halfway."""
    existing = {}
    for shot in asc.call(f"appEventLocalizations/{localization_id}/appEventScreenshots")["data"]:
        existing.setdefault(shot["attributes"]["appEventAssetType"], []).append(shot)
    notes = []
    for asset_type, prefix in ASSETS:
        good = [s for s in existing.get(asset_type, [])
                if s["attributes"]["assetDeliveryState"]["state"] == "COMPLETE"]
        if good:
            notes.append(f"{asset_type.lower()} ok")
            continue
        for stale in existing.get(asset_type, []):
            asc.call(f"appEventScreenshots/{stale['id']}", method="DELETE")
        attach(localization_id, asset_type, os.path.join(ART, f"{prefix}-{locale}.png"))
        notes.append(f"{asset_type.lower()} sent")
    return ", ".join(notes)


def find_event() -> str | None:
    for event in asc.call(f"apps/{APP}/appEvents", params={"limit": 20})["data"]:
        if event["attributes"]["referenceName"] == REFERENCE_NAME:
            return event["id"]
    return None


def main() -> None:
    event_id = find_event()
    if event_id:
        print(f"event {event_id} is already there, filling in what is missing")
    else:
        where = territories()
        event_id = create_event(where)
        print(f"event {event_id} created over {len(where)} territories, "
              f"{PUBLISH_START[:10]} → {EVENT_END[:10]}")
    known = localizations(event_id)
    for locale in EVENT:
        localization_id = known.get(locale) or localize(event_id, locale)
        state = "kept" if locale in known else "created"
        print(f"{locale:8} {state:8} {sync_pictures(localization_id, locale)}")
    print("draft ready; it is submitted from App Store Connect, by a person")


if __name__ == "__main__":
    main()
