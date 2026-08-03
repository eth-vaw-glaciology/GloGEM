#!/usr/bin/env python3
"""Sync CITATION.cff version/date-released with a new GitHub release, and
regenerate the APA/BibTeX text embedded in README.md and docs/source/index.md
so all three stay consistent with CITATION.cff.

Reads RELEASE_TAG (e.g. "v0.1.2") and RELEASE_DATE (ISO 8601, e.g.
"2026-08-01T12:00:00Z") from the environment. Run from CI on `release:
published`, or locally against a scratch copy of the repo for testing.
"""
import os
import re
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
CITATION_FILE = REPO_ROOT / "CITATION.cff"
README_FILE = REPO_ROOT / "README.md"
DOCS_INDEX_FILE = REPO_ROOT / "docs" / "source" / "index.md"

APA_START, APA_END = "<!-- CITATION:APA:START -->", "<!-- CITATION:APA:END -->"
BIBTEX_START, BIBTEX_END = "<!-- CITATION:BIBTEX:START -->", "<!-- CITATION:BIBTEX:END -->"


def get_release_info():
    tag = os.environ["RELEASE_TAG"].lstrip("vV")
    date = os.environ["RELEASE_DATE"].split("T")[0]
    return tag, date


def update_cff_fields(version, date):
    text = CITATION_FILE.read_text()
    text = re.sub(r"(?m)^version: .*$", f"version: {version}", text)
    text = re.sub(r"(?m)^date-released: .*$", f"date-released: {date}", text)
    CITATION_FILE.write_text(text)


def release_year(data):
    released = data["date-released"]
    return released.split("-")[0] if isinstance(released, str) else released.year


def format_authors_apa(authors):
    parts = []
    for a in authors:
        initials = " ".join(f"{w[0]}." for w in a["given-names"].split())
        parts.append(f"{a['family-names']}, {initials}")
    if len(parts) == 1:
        return parts[0]
    return ", ".join(parts[:-1]) + f", & {parts[-1]}"


def format_apa(data, version):
    author_str = format_authors_apa(data["authors"])
    year = release_year(data)
    return (
        f"{author_str} ({year}). {data['title']} (Version {version}) "
        f"[Computer software]. https://doi.org/{data['doi']}"
    )


def format_bibtex(data):
    authors = " and ".join(f"{a['family-names']}, {a['given-names']}" for a in data["authors"])
    first_family = data["authors"][0]["family-names"].split()[-1].lower()
    year = release_year(data)
    key = f"{first_family}{year}glogem"
    return (
        f"@misc{{{key},\n"
        f"  author = {{{authors}}},\n"
        f"  title  = {{{data['title']}}},\n"
        f"  year   = {{{year}}},\n"
        f"  doi    = {{{data['doi']}}},\n"
        f"  url    = {{https://doi.org/{data['doi']}}}\n"
        f"}}"
    )


def replace_between_markers(text, start_marker, end_marker, new_content):
    pattern = re.compile(re.escape(start_marker) + r".*?" + re.escape(end_marker), re.DOTALL)
    replacement = f"{start_marker}\n{new_content}\n{end_marker}"
    return pattern.sub(replacement, text, count=1)


def main():
    version, date = get_release_info()
    update_cff_fields(version, date)

    data = yaml.safe_load(CITATION_FILE.read_text())
    apa_text = format_apa(data, version)
    bibtex_text = format_bibtex(data)

    readme = README_FILE.read_text()
    readme = replace_between_markers(readme, APA_START, APA_END, f"> {apa_text}")
    README_FILE.write_text(readme)

    docs_index = DOCS_INDEX_FILE.read_text()
    docs_index = replace_between_markers(docs_index, APA_START, APA_END, apa_text)
    docs_index = replace_between_markers(
        docs_index, BIBTEX_START, BIBTEX_END, f"```bibtex\n{bibtex_text}\n```"
    )
    DOCS_INDEX_FILE.write_text(docs_index)


if __name__ == "__main__":
    main()
