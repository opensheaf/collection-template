#!/usr/bin/env python3
"""Change the members of the collection as described by an issue form.

Run by .github/workflows/from-issue.yml, in the root of the collection,
after the workflow has checked that the issue's author may write to the
repository. Reads the issue from the event file (GITHUB_EVENT_PATH), never
from the command line; changes collection.yaml; runs `osheaf collection
sync --from collection.yaml`, `osheaf index` and `osheaf verify`; writes a
message for the issue to RESULT_FILE (Markdown), the commit message to
COMMIT_FILE and the issue's new title to TITLE_FILE. Exits 0 on success, 1
on an error the curator can fix (explained in RESULT_FILE), 2 if the issue
is not one of the forms.

The result is the same as editing collection.yaml by hand and running the
commands of the README.
"""
import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

import yaml

OSHEAF = shlex.split(os.environ.get("OSHEAF", "osheaf"))
NO_RESPONSE = "_No response_"
IDENT = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
COLLECTION = Path("collection.yaml")
HEADER = """\
# The members of the collection, in order, for
# `osheaf collection sync --from collection.yaml`: kept by the issue forms of
# this repository (Issues, New issue) or by hand (see the README). Each member
# is an object of an OpenSheaf archive: the archive's address and the
# object's identifier; in a selection, `revisions` lists the document
# versions vetted (1, 2, ...).
"""

# The heading that identifies each form (a label of one of its fields).
FORMS = {
    "Archive of the new member": "add",
    "Versions to vet": "vet",
    "Member to remove": "remove",
}


class Problem(Exception):
    """An error the curator can fix, explained in plain words."""


def sections(body):
    out, label, lines = {}, None, []
    for line in (body or "").splitlines():
        m = re.match(r"^### (.+?)\s*$", line)
        if m:
            if label is not None:
                out[label] = "\n".join(lines).strip()
            label, lines = m.group(1), []
        elif label is not None:
            lines.append(line)
    if label is not None:
        out[label] = "\n".join(lines).strip()
    return {k: ("" if v == NO_RESPONSE else v) for k, v in out.items()}


def field(form, label, required=False):
    value = form.get(label, "").strip()
    if required and not value:
        raise Problem(f"The field **{label}** is empty, and it is needed.")
    return value


def identifier(form, label):
    ident = field(form, label, required=True)
    if not IDENT.match(ident) or len(ident) > 64:
        raise Problem(f"`{ident}` is not an object identifier: lower-case letters and digits, "
                      "words joined by `-` (as in the object's address, `.../paper/IDENTIFIER/`).")
    return ident


def archive_url(form, label, required=True):
    url = field(form, label, required)
    if not url:
        return ""
    if not re.match(r"^https?://\S+$", url):
        raise Problem(f"**{label}** should be the address of an OpenSheaf archive, the folder "
                      f"that holds its `opensheaf.json` (for instance `https://mgubi.org/papers/`), "
                      f"not `{url}`.")
    url = re.sub(r"opensheaf\.json$", "", url)
    return url if url.endswith("/") else url + "/"


def versions(form, label, required=False):
    text = field(form, label, required)
    found = re.findall(r"\d+", text)
    if text and (not found or re.sub(r"[\d,;\s]", "", text)):
        raise Problem(f"**{label}** should be document versions, numbers such as `5` or `5, 6`, "
                      f"not `{text}`.")
    return [int(n) for n in found]


def load():
    if not COLLECTION.exists():
        raise Problem("`collection.yaml` is missing: run the workflow **Set up the collection** "
                      "first (Actions tab).")
    data = yaml.safe_load(COLLECTION.read_text(encoding="utf-8")) or {}
    data.setdefault("members", [])
    if data["members"] is None:
        data["members"] = []
    return data


def save(data):
    text = yaml.safe_dump(data, sort_keys=False, allow_unicode=True, width=100)
    COLLECTION.write_text(HEADER + text, encoding="utf-8")


def find(data, ident, archive=""):
    hits = [m for m in data["members"] if m.get("id") == ident
            and (not archive or str(m.get("archive", "")).rstrip("/") + "/" == archive)]
    if not hits:
        raise Problem(f"`{ident}` is not a member of the collection"
                      + (f" from `{archive}`" if archive else "") + ".")
    if len(hits) > 1:
        raise Problem(f"Several members are called `{ident}`: give **Archive of the member** to "
                      "say which.")
    return hits[0]


def osheaf(*args):
    result = subprocess.run(OSHEAF + [str(a) for a in args], capture_output=True, text=True)
    if result.returncode != 0:
        lines = (result.stderr or result.stdout).strip().splitlines()
        errors = [l for l in lines if l.startswith("osheaf: error:")]
        raise Problem("osheaf stopped with this message:\n\n```\n"
                      + "\n".join(errors or lines[-15:]) + "\n```")
    return result.stdout


def add(form, data):
    archive = archive_url(form, "Archive of the new member")
    ident = identifier(form, "Identifier of the new member")
    revisions = versions(form, "Versions you vet (selection)")
    if any(m.get("id") == ident and str(m.get("archive", "")).rstrip("/") + "/" == archive
           for m in data["members"]):
        raise Problem(f"`{ident}` from `{archive}` is already a member.")
    if revisions and data.get("type") != "selection":
        raise Problem("Versions are vetted only in a selection; this collection is a catalogue, "
                      "which follows its members whatever they hold. Leave **Versions you vet** "
                      "empty.")
    member = {"archive": archive, "id": ident}
    if revisions:
        member["revisions"] = revisions
    position = field(form, "Position")
    if position and not position.isdigit():
        raise Problem(f"**Position** should be a number (1 for the first), not `{position}`.")
    if position and 1 <= int(position) <= len(data["members"]):
        data["members"].insert(int(position) - 1, member)
    else:
        data["members"].append(member)
    return ident, f"add {ident} from {archive}", f"Member added: {ident}", f"`{ident}` was added"


def vet(form, data):
    if data.get("type") != "selection":
        raise Problem("Versions are vetted only in a selection; this collection is a catalogue, "
                      "which follows its members (run **Update the collection** in the Actions "
                      "tab to move them on).")
    ident = identifier(form, "Member")
    member = find(data, ident, archive_url(form, "Archive of the member", required=False))
    new = versions(form, "Versions to vet", required=True)
    old = list(member.get("revisions") or [])
    added = [v for v in new if v not in old]
    if not added:
        raise Problem(f"`{ident}` already has the versions {', '.join(map(str, new))} vetted.")
    member["revisions"] = sorted(old + added)
    vs = ", ".join(map(str, added))
    return (ident, f"vet version {vs} of {ident}", f"Vetted: {ident}, version {vs}",
            f"version {vs} of `{ident}` was vetted")


def remove(form, data):
    ident = identifier(form, "Member to remove")
    member = find(data, ident, archive_url(form, "Archive of the member", required=False))
    data["members"].remove(member)
    return ident, f"remove {ident}", f"Member removed: {ident}", f"`{ident}` was removed"


OPERATIONS = {"add": add, "vet": vet, "remove": remove}


def main():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    issue = event["issue"]
    form = sections(issue.get("body"))
    kind = next((FORMS[h] for h in FORMS if h in form), None)
    result_file = Path(os.environ.get("RESULT_FILE", "result.md"))
    if kind is None:
        result_file.write_text("This issue is not one of the collection's forms.\n",
                               encoding="utf-8")
        return 2
    original = COLLECTION.read_text(encoding="utf-8") if COLLECTION.exists() else None
    try:
        if not Path("osheaf.json").exists():
            raise Problem("The collection is not set up yet: run the workflow **Set up the "
                          "collection** first (Actions tab), then open the issue again.")
        data = load()
        ident, what, title, done = OPERATIONS[kind](form, data)
        why = field(form, "Why (optional)")
        save(data)
        message = f"{what[0].upper()}{what[1:]} (issue #{issue['number']})" + (f": {why}" if why else "")
        osheaf("collection", "sync", "--from", COLLECTION, "--message", message)
        osheaf("index")
        osheaf("verify")
    except Problem as p:
        if original is not None:
            COLLECTION.write_text(original, encoding="utf-8")  # the list as it was
        result_file.write_text(
            f"Nothing was changed in the collection.\n\n{p}\n\n"
            "Edit this issue to correct it, then close and reopen it to try again.\n",
            encoding="utf-8")
        return 1
    base = json.loads(Path("osheaf.json").read_text(encoding="utf-8")).get("baseUrl", "")
    result_file.write_text(
        f"Done: {done}.\n\nThe collection's page, <{base}>, shows it once GitHub Pages has "
        "published the site (usually within a few minutes).\n", encoding="utf-8")
    Path(os.environ.get("COMMIT_FILE", "commit.txt")).write_text(message + "\n", encoding="utf-8")
    Path(os.environ.get("TITLE_FILE", "title.txt")).write_text(title + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
