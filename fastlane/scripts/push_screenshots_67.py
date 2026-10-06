"""The October iPhone slides (1290 x 2796, the 6.9" slot) onto a new iOS version.

    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_screenshots_67.py 1.37 --dry-run
    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_screenshots_67.py 1.37 --solo-backup
    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_screenshots_67.py 1.37
    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_screenshots_67.py 1.37 --ripristina [--dry-run]

What a real run does, in this order, and stops at the first thing that does not add up:
  1. creates the iOS version (MANUAL, same copyright as the live one) if it does not exist;
  2. checks that every locale below exists on it (pt-BR included);
  3. downloads the old 6.5" slides of the live version (BACKUP_FROM) into
     fastlane/screenshots/_backup-<BACKUP_FROM>/<locale>/ (git-ignored);
  4. per locale: new APP_IPHONE_67 set, five uploads in order, waits for COMPLETE,
     checks the order; only then deletes that locale's APP_IPHONE_65 set
     (iPad sets and es-ES are never touched).
Re-runnable: a locale whose 67 set already holds the five files is skipped.

--ripristina: per locale, deletes the 67 set and puts the 6.5" backup back as an
APP_IPHONE_65 set. It does not delete the version: that is printed, not done.
"""
import argparse, hashlib, os, re, sys, time, urllib.request
from PIL import Image
import asc

APP = "1659625843"
ROOT = asc.ROOT
SRC = os.path.join(ROOT, "fastlane/screenshots-src/out-v2")
BACKUP_FROM = "1.36"
BACKUP_DIR = os.path.join(ROOT, f"fastlane/screenshots/_backup-{BACKUP_FROM}")
FILES = ["screenshot_1.png", "screenshot_2.png", "screenshot_3.png",
         "screenshot_5.png", "screenshot_6.png"]
SIZE = (1290, 2796)
NEW, OLD = "APP_IPHONE_67", "APP_IPHONE_65"
# store locale -> folder of out-v2
LOCALES = {"en-US": "en", "it": "it", "es-MX": "es", "de-DE": "de",
           "fr-FR": "fr", "fr-CA": "fr", "nl-NL": "nl", "pt-BR": "pt-BR"}
# pt-BR has no 6.5" set of its own: nothing to back up or delete there
DELETE_OLD = [l for l in LOCALES if l != "pt-BR"]
COPYRIGHT = "© Balzo 2026"

DRY = False


def write(path, method, body=None):
    """Every write goes through here, so a dry run cannot write by accident."""
    if DRY:
        print(f"    [dry-run] {method} /v1/{path}")
        return None
    return asc.call(path, method=method, body=body)


def find_version(vs):
    rows = asc.call(f"apps/{APP}/appStoreVersions",
                    params={"filter[versionString]": vs, "filter[platform]": "IOS"})["data"]
    return rows[0] if rows else None


def localizations(version_id):
    return {r["attributes"]["locale"]: r["id"] for r in asc.call(
        f"appStoreVersions/{version_id}/appStoreVersionLocalizations",
        params={"limit": 50})["data"]}


def sets_of(loc_id):
    return {r["attributes"]["screenshotDisplayType"]: r["id"] for r in asc.call(
        f"appStoreVersionLocalizations/{loc_id}/appScreenshotSets", params={"limit": 20})["data"]}


def shots(set_id):
    rows = asc.call(f"appScreenshotSets/{set_id}/appScreenshots", params={"limit": 20})["data"]
    order = [r["id"] for r in asc.call(
        f"appScreenshotSets/{set_id}/relationships/appScreenshots", params={"limit": 20})["data"]]
    by_id = {r["id"]: r for r in rows}
    return [by_id[i] for i in order if i in by_id]


def describe(set_id):
    out = []
    for s in shots(set_id):
        ia = s["attributes"].get("imageAsset") or {}
        st = (s["attributes"].get("assetDeliveryState") or {}).get("state")
        out.append(f"{s['attributes']['fileName']} {ia.get('width')}x{ia.get('height')} {st}")
    return out


def check_files():
    for folder in sorted(set(LOCALES.values())):
        for name in FILES:
            path = os.path.join(SRC, folder, name)
            if not os.path.exists(path):
                raise SystemExit(f"manca {path}")
            if Image.open(path).size != SIZE:
                raise SystemExit(f"{path} non è {SIZE}")


def backup(force=False):
    """The live version's 6.5" slides, at full size, numbered in their order."""
    live = find_version(BACKUP_FROM)
    if live["attributes"]["appStoreState"] != "READY_FOR_SALE":
        raise SystemExit(f"{BACKUP_FROM} non è READY_FOR_SALE")
    locs = localizations(live["id"])
    for locale in DELETE_OLD:
        set_id = sets_of(locs[locale]).get(OLD)
        if not set_id:
            raise SystemExit(f"{BACKUP_FROM} {locale}: nessun {OLD} da salvare")
        folder = os.path.join(BACKUP_DIR, locale)
        rows = shots(set_id)
        if DRY:
            print(f"  [dry-run] backup {locale}: {len(rows)} file -> {folder}")
            continue
        os.makedirs(folder, exist_ok=True)
        for n, s in enumerate(rows, 1):
            ia = s["attributes"]["imageAsset"]
            url = (ia["templateUrl"].replace("{w}", str(ia["width"]))
                   .replace("{h}", str(ia["height"])).replace("{f}", "png"))
            safe = re.sub(r"[^A-Za-z0-9._-]+", "_", s["attributes"]["fileName"])
            path = os.path.join(folder, f"{n:02d}_{safe}")
            if os.path.exists(path) and not force:
                continue
            with urllib.request.urlopen(url, timeout=120) as r:
                data = r.read()
            with open(path, "wb") as h:
                h.write(data)
            if Image.open(path).size != (ia["width"], ia["height"]):
                raise SystemExit(f"backup {path}: misura diversa da {ia['width']}x{ia['height']}")
        print(f"  backup {locale}: {len(rows)} file in {folder}")


def upload(set_id, path):
    with open(path, "rb") as h:
        data = h.read()
    created = asc.call("appScreenshots", method="POST", body={"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": os.path.basename(path), "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    sid = created["data"]["id"]
    for op in created["data"]["attributes"]["uploadOperations"]:
        asc.upload_part(op, data[op["offset"]:op["offset"] + op["length"]])
    asc.call(f"appScreenshots/{sid}", method="PATCH", body={"data": {
        "type": "appScreenshots", "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    return sid


def wait_complete(set_id, expected_names, minutes=10):
    deadline = time.time() + minutes * 60
    while True:
        rows = shots(set_id)
        states = [(s["attributes"].get("assetDeliveryState") or {}).get("state") for s in rows]
        if "FAILED" in states:
            raise SystemExit(f"set {set_id}: upload FAILED {describe(set_id)}")
        if len(rows) == len(expected_names) and all(st == "COMPLETE" for st in states):
            names = [s["attributes"]["fileName"] for s in rows]
            if names != expected_names:
                raise SystemExit(f"set {set_id}: ordine {names}, atteso {expected_names}")
            return
        if time.time() > deadline:
            raise SystemExit(f"set {set_id}: non COMPLETE dopo {minutes} min: {states}")
        time.sleep(10)


def new_set(loc_id, display):
    created = write("appScreenshotSets", "POST", {"data": {
        "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display},
        "relationships": {"appStoreVersionLocalization": {
            "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})
    return created["data"]["id"] if created else "<nuovo>"


def push(vs):
    check_files()
    version = find_version(vs)
    if version is None:
        live = find_version(BACKUP_FROM)
        print(f"versione {vs} assente: POST /v1/appStoreVersions IOS {vs} MANUAL «{COPYRIGHT}»")
        created = write("appStoreVersions", "POST", {"data": {
            "type": "appStoreVersions",
            "attributes": {"platform": "IOS", "versionString": vs,
                           "releaseType": "MANUAL", "copyright": COPYRIGHT},
            "relationships": {"app": {"data": {"type": "apps", "id": APP}}}}})
        if DRY:
            print(f"  [dry-run] le localizzazioni e i set si leggono dalla {BACKUP_FROM}, "
                  "da cui la versione nuova li eredita")
            version = live
        else:
            version = asc.call(f"appStoreVersions/{created['data']['id']}")["data"]
    a = version["attributes"]
    print(f"versione {a['versionString']} id={version['id']} {a['appStoreState']}")
    if not DRY and (a["versionString"] != vs or a["appStoreState"] != "PREPARE_FOR_SUBMISSION"):
        raise SystemExit(f"versione inattesa: {a['versionString']} {a['appStoreState']}")
    locs = localizations(version["id"])
    missing = [l for l in LOCALES if l not in locs]
    if missing:
        raise SystemExit(f"localizzazioni mancanti su {vs}: {missing}")
    backup()
    for locale, folder in LOCALES.items():
        sets = sets_of(locs[locale])
        print(f"\n{locale} (loc {locs[locale]}) <- out-v2/{folder}")
        for t, sid in sets.items():
            print(f"  ora {t} {sid}: {describe(sid)}")
        names = FILES
        set67 = sets.get(NEW)
        if set67:
            got = [s["attributes"]["fileName"] for s in shots(set67)]
            if got == names:
                print(f"  {NEW} già pieno e in ordine: salto l'upload")
            else:
                raise SystemExit(f"  {NEW} esiste con {got}: mi fermo")
        else:
            set67 = new_set(locs[locale], NEW)
            for name in names:
                path = os.path.join(SRC, folder, name)
                if DRY:
                    print(f"    [dry-run] upload {path}")
                else:
                    upload(set67, path)
            if not DRY:
                wait_complete(set67, names)
                print(f"  {NEW} {set67}: {describe(set67)}")
        if locale in DELETE_OLD and sets.get(OLD):
            if not DRY and not os.listdir(os.path.join(BACKUP_DIR, locale)):
                raise SystemExit(f"  nessun backup per {locale}: non cancello")
            write(f"appScreenshotSets/{sets[OLD]}", "DELETE")
            print(f"  {OLD} {sets[OLD]} cancellato" if not DRY else f"  cancellerei {OLD} {sets[OLD]}")
    print(f"\nripristino: PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_screenshots_67.py {vs} --ripristina")


def restore(vs):
    version = find_version(vs)
    if not version:
        raise SystemExit(f"nessuna versione {vs}")
    if version["attributes"]["appStoreState"] != "PREPARE_FOR_SUBMISSION":
        raise SystemExit(f"{vs} è {version['attributes']['appStoreState']}: non la tocco")
    locs = localizations(version["id"])
    for locale in LOCALES:
        sets = sets_of(locs[locale])
        print(f"\n{locale}")
        if sets.get(NEW):
            write(f"appScreenshotSets/{sets[NEW]}", "DELETE")
            print(f"  {NEW} {sets[NEW]} cancellato")
        if locale not in DELETE_OLD or sets.get(OLD):
            continue
        folder = os.path.join(BACKUP_DIR, locale)
        files = sorted(os.listdir(folder))
        set65 = new_set(locs[locale], OLD)
        for name in files:
            if DRY:
                print(f"    [dry-run] upload {os.path.join(folder, name)}")
            else:
                upload(set65, os.path.join(folder, name))
        if not DRY:
            wait_complete(set65, files)
            print(f"  {OLD} {set65}: {describe(set65)}")
    print(f"\nla versione resta. Per cancellarla (solo se mai inviata): "
          f"DELETE /v1/appStoreVersions/{version['id']}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("version")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--ripristina", action="store_true")
    p.add_argument("--solo-backup", action="store_true")
    args = p.parse_args()
    DRY = args.dry_run
    if args.solo_backup:
        backup()
    elif args.ripristina:
        restore(args.version)
    else:
        push(args.version)
