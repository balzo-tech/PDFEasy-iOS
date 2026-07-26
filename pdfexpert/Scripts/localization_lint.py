#!/usr/bin/env python3
#
#  localization_lint.py
#  PdfExpert
#
#  Catches user-facing text that will never reach a translator, and translations
#  that would crash or reflow at runtime. Run it by hand or through
#  `bundle exec fastlane lint`; output is in Xcode's `file:line: error:` format,
#  so it also reads correctly if wired up as a build phase.
#
#  Three checks, each of which has already caught a real bug in this project:
#
#  1. UNTRANSLATED KEY — a literal sits in a construct that localizes
#     (`Text("…")`, `String(localized: "…")`, `Label("…", systemImage:)`, …) but
#     the string catalog has no entry for it, or has one without every language.
#     Phase 8 shipped twelve of these: the iPad sidebar read "Folders" to an
#     Italian user because the keys had never been extracted.
#
#  2. RAW STRING TEXT — a `return "Some sentence"` inside a view or view model,
#     not wrapped in `String(localized:)`. A `String` reaches `Text` through the
#     verbatim overload, so it is never localized no matter what the catalog
#     says. `CameraError` did this for its whole alert.
#
#  3. BROKEN TRANSLATION — a translation whose placeholder set (%@ / %lld / %%,
#     positional or not) or newline count differs from the source. A lost
#     placeholder is a crash at format time; a lost newline silently reflows a
#     two-line title.
#
#  Exit status is 0 when clean, 1 when anything is reported.
#
#  Adding an exception: put the string in ALLOWED_RAW_STRINGS below with a
#  reason. There is deliberately no way to silence check 1 or 3 — a literal that
#  should not be translated belongs in `Text(verbatim:)`, which this script
#  ignores.

from __future__ import annotations

import json
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Every catalog, with the languages it is expected to carry.
CATALOGS = [
    ("pdfexpert/Resources/Localizable.xcstrings", ("it", "es")),
    ("PdfProWidget/Localizable.xcstrings", ("it", "es")),
]

# Source trees to scan, mapped to the catalog that should cover them.
SOURCE_TREES = [
    ("pdfexpert", "pdfexpert/Resources/Localizable.xcstrings"),
    ("PdfProWidget", "PdfProWidget/Localizable.xcstrings"),
    ("ShareFileExtension", "pdfexpert/Resources/Localizable.xcstrings"),
]

SKIP_DIR_NAMES = {"Generated", "Preview Content", "DerivedData", ".git", "build"}

# A Swift string literal body: anything but an unescaped quote.
LIT = r'"((?:[^"\\]|\\.)*)"'

# Constructs whose string argument SwiftUI (or our own helper) localizes.
LOCALIZING_PATTERNS = [
    rf"String\(localized:\s*{LIT}",
    rf"\bText\(\s*{LIT}\s*\)",
    rf"\bLabel\(\s*{LIT}\s*,\s*systemImage",
    rf"\bButton\(\s*{LIT}",
    rf"\.navigationTitle\(\s*{LIT}\s*\)",
    rf"\.alert\(\s*{LIT}",
    rf"\bSection\(\s*{LIT}",
    rf"\bCommandMenu\(\s*{LIT}",
    rf"\.accessibilityLabel\(Text\(\s*{LIT}",
    rf"\.accessibilityHint\(Text\(\s*{LIT}",
    rf"prompt:\s*Text\(\s*{LIT}",
]

# `return "…"` bodies that look like prose rather than an identifier. The literal
# has to end the statement, but closing braces may follow it — a one-line
# accessor (`var x: String { return "…" }`) is the same bug as a switch case.
RAW_STRING_PATTERNS = [
    rf"\breturn\s+{LIT}\s*\}}*\s*(?://.*)?$",
]

# Declarations whose type localizes a bare literal on its own, so a `return "…"`
# inside them is already correct. `LocalizedStringResource` is
# ExpressibleByStringLiteral and resolves against the catalog; `Text` and
# `LocalizedStringKey` likewise.
SELF_LOCALIZING_TYPES = ("LocalizedStringResource", "LocalizedStringKey")

# The enclosing declaration's type: `var foo: T {` or `func foo(…) -> T {`.
DECLARATION_TYPE = re.compile(r"\b(?:var\s+\w+\s*:|->)\s*([A-Za-z0-9_.<>\[\]?]+)")

# Files whose prose strings are never shown to anyone, with the reason.
ALLOWED_FILES = {
    "pdfexpert/Models/Analytics/AnalyticsDefaultParameters.swift":
        "analytics event and error descriptions — wire values read by dashboards, "
        "translating them would break every existing report",
}

# Individual strings that look like prose but are not user-facing text.
ALLOWED_RAW_STRINGS = {
    "File-\\(dateFormatter.string(from: self))":
        "generated filename, not a sentence — a localized month name here would "
        "produce filenames that differ per device language",
    "Scan \\(formatter.string(from: date))":
        "same reason: the name a scan is offered before the user types one. The "
        "formatter is pinned to en_US_POSIX so a scan taken abroad still sorts "
        "next to the others",
}


class Finding:
    def __init__(self, path: str, line: int, kind: str, message: str):
        self.path = path
        self.line = line
        self.kind = kind
        self.message = message

    def __str__(self) -> str:
        rel = os.path.relpath(self.path, REPO_ROOT)
        return f"{rel}:{self.line}: error: [{self.kind}] {self.message}"

    @property
    def identity(self) -> tuple:
        """Two patterns can match the same line; report it once."""
        return (self.path, self.line, self.kind, self.message)


def unescape(literal: str) -> str:
    """Swift literal body -> the runtime string, which is what the catalog keys on."""
    return (literal
            .replace("\\n", "\n")
            .replace("\\t", "\t")
            .replace('\\"', '"')
            .replace("\\\\", "\\"))


def placeholders(text: str) -> list[str]:
    """Normalized format specifiers: %1$@ and %@ compare equal."""
    return sorted(kind for _, kind in re.findall(r"%(?:(\d+)\$)?(@|lld|%)", text))


def load_catalog(relative_path: str) -> dict:
    with open(os.path.join(REPO_ROOT, relative_path)) as handle:
        return json.load(handle)


def swift_files(tree: str):
    root = os.path.join(REPO_ROOT, tree)
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIR_NAMES]
        for name in sorted(names):
            if name.endswith(".swift"):
                yield os.path.join(base, name)


def value_of(localization: dict) -> str | None:
    """The string of a localization, or None when it is a plural set."""
    unit = localization.get("stringUnit")
    return unit.get("value") if unit else None


def check_translations(relative_path: str, languages) -> list[Finding]:
    """Check 3, plus a report of any key missing a language at all."""
    catalog = load_catalog(relative_path)
    path = os.path.join(REPO_ROOT, relative_path)
    findings = []
    for key, entry in sorted(catalog.get("strings", {}).items()):
        localizations = entry.get("localizations", {})
        if not key.strip():
            findings.append(Finding(path, 1, "empty-key",
                                    "the catalog has a blank key — it comes from a "
                                    'Text("") somewhere; use a non-text view instead'))
            continue
        for language in languages:
            localization = localizations.get(language)
            if localization is None:
                findings.append(Finding(path, 1, "missing-translation",
                                        f"{key!r} has no {language} translation"))
                continue
            translated = value_of(localization)
            if translated is None:
                # Plural set: every variation has to hold up on its own.
                variations = localization.get("variations", {}).get("plural", {})
                for category, unit in sorted(variations.items()):
                    translated = value_of(unit) or ""
                    if placeholders(key) != placeholders(translated):
                        findings.append(Finding(
                            path, 1, "broken-translation",
                            f"{key!r} [{language}/{category}] placeholders "
                            f"{placeholders(translated)} != source {placeholders(key)}"))
                continue
            if placeholders(key) != placeholders(translated):
                findings.append(Finding(
                    path, 1, "broken-translation",
                    f"{key!r} [{language}] placeholders {placeholders(translated)} "
                    f"!= source {placeholders(key)}"))
            if key.count("\n") != translated.count("\n"):
                findings.append(Finding(
                    path, 1, "broken-translation",
                    f"{key!r} [{language}] has {translated.count(chr(10))} newlines, "
                    f"source has {key.count(chr(10))}"))
    return findings


def check_sources() -> list[Finding]:
    """Checks 1 and 2."""
    catalogs = {path: load_catalog(path) for path, _ in CATALOGS}
    languages = dict(CATALOGS)
    findings = []

    for tree, catalog_path in SOURCE_TREES:
        keys = catalogs[catalog_path]["strings"]
        expected = languages[catalog_path]
        for path in swift_files(tree):
            relative = os.path.relpath(path, REPO_ROOT)
            skip_raw = relative in ALLOWED_FILES
            with open(path) as handle:
                lines = handle.readlines()
            enclosing_type = ""
            for number, line in enumerate(lines, start=1):
                # Comments and previews are not shipped text.
                if line.lstrip().startswith("//"):
                    continue

                declaration = DECLARATION_TYPE.search(line)
                if declaration:
                    enclosing_type = declaration.group(1)

                for pattern in LOCALIZING_PATTERNS:
                    for match in re.finditer(pattern, line):
                        literal = unescape(match.group(1))
                        if not literal.strip():
                            findings.append(Finding(
                                path, number, "empty-key",
                                "empty literal in a localizing construct; use a "
                                "non-text view (Color.clear) as an anchor instead"))
                            continue
                        # An interpolated literal becomes a %-format key that we
                        # cannot reconstruct reliably; the catalog check covers it.
                        if "\\(" in match.group(1):
                            continue
                        entry = keys.get(literal)
                        if entry is None:
                            findings.append(Finding(
                                path, number, "untranslated-key",
                                f"{literal!r} is not in "
                                f"{os.path.basename(catalog_path)} — it will show in "
                                "English in every language"))
                            continue
                        present = entry.get("localizations", {})
                        for language in expected:
                            if language not in present:
                                findings.append(Finding(
                                    path, number, "untranslated-key",
                                    f"{literal!r} has no {language} translation"))

                if skip_raw or enclosing_type in SELF_LOCALIZING_TYPES:
                    continue
                for pattern in RAW_STRING_PATTERNS:
                    for match in re.finditer(pattern, line.rstrip()):
                        literal = match.group(1)
                        if literal in ALLOWED_RAW_STRINGS:
                            continue
                        literal = unescape(literal)
                        if not looks_like_prose(literal):
                            continue
                        findings.append(Finding(
                            path, number, "raw-string-text",
                            f"{literal!r} is returned as a plain String. If it is "
                            "shown to the user, wrap it in String(localized:) — a "
                            "String reaches Text through the verbatim overload and "
                            "is never localized. If it is not, add it to "
                            "ALLOWED_RAW_STRINGS with a reason."))
    return findings


def looks_like_prose(text: str) -> bool:
    """
    Heuristic for "a human is meant to read this". Sentences have a space and
    start with a capital; identifiers, symbol names, keys and formats do not.
    Keeps the raw-string check quiet enough to be worth running.
    """
    stripped = text.strip()
    if len(stripped) < 4 or " " not in stripped:
        return False
    if not stripped[0].isupper():
        return False
    # SF Symbol names and reverse-DNS identifiers.
    if re.fullmatch(r"[A-Za-z0-9._-]+", stripped):
        return False
    return True


def main() -> int:
    collected = check_sources()
    for relative_path, languages in CATALOGS:
        collected.extend(check_translations(relative_path, languages))

    seen = set()
    findings = []
    for finding in collected:
        if finding.identity in seen:
            continue
        seen.add(finding.identity)
        findings.append(finding)

    if not findings:
        print("localization_lint: clean")
        return 0

    by_kind: dict[str, int] = {}
    for finding in findings:
        print(finding)
        by_kind[finding.kind] = by_kind.get(finding.kind, 0) + 1

    summary = ", ".join(f"{count} {kind}" for kind, count in sorted(by_kind.items()))
    print(f"\nlocalization_lint: {len(findings)} problem(s) — {summary}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
