# Store scripts

What `fastlane` cannot do here, and why these exist.

`deliver` — the engine behind the `metadata` lanes — asks App Store Connect for
the **app info** before it writes anything. The app info holds the name and the
subtitle, it is shared by every platform of the app, and it is frozen while
*any* version is in review. The Mac 1.28 has been in review since 20 August, so
every `deliver` run spends ten minutes retrying

    Cannot find edit app info... Retrying after 20 seconds

and then fails — taking the description, the keywords, the release notes and the
promotional text with it, none of which were ever blocked: those belong to the
version, and the version is editable. Removing `name.txt` and `subtitle.txt`
from what deliver reads does not help; it asks for the app info either way.

These talk to the API that knows the difference. They need `fastlane/.env`
(`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILEPATH`) and nothing else, and they
are run from the project root:

    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_texts.py 1.32
    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_screenshots.py 1.32 nl-NL fastlane/screenshots/nl-NL
    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/event_art.py      # writes event-art/
    PYTHONPATH=fastlane/scripts python3 fastlane/scripts/create_event.py

| file | what it does |
| --- | --- |
| `asc.py` | the API client: the JWT, the call, and the asset upload |
| `push_texts.py` | description, keywords, release notes, promotional text, per locale, onto a version |
| `push_screenshots.py` | one language's slides onto a version, when a set is missing |
| `event_text.py` | what the in-app event says, in every language, with the field limits |
| `event_art.py` | the two pictures every localisation of an event needs |
| `create_event.py` | creates the event as a **draft** and fills it in; re-runnable |

None of them submits anything. `create_event.py` leaves the event in DRAFT: a
person submits it from App Store Connect, and only once the version it talks
about is live — the event and the version are two separate review queues, and a
card that promises a tool the live app does not have is the one way this gets
turned down.

Prefer the fastlane lanes when they work. These are the way round a blockage,
not a replacement.
