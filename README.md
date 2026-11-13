# An OpenSheaf collection

> [!WARNING]
> **Draft.** OpenSheaf 0.1 is a draft specification. Until version 1.0, any
> revision may change the format in incompatible ways. Archives and collections made now
> may have to be rebuilt or migrated, and the tools follow the latest draft.
> Do not rely on it yet for anything you cannot redo.

A template for a curated collection of papers kept in other archives: a
reading list, the papers of a group, a seminar, a special issue. Nothing is
copied: each member is an object of an [OpenSheaf](https://opensheaf.org)
archive, pinned by the SHA-512 digest of an inventory, so that the
collection fixes exactly what it lists, and anyone can check it.

A collection is one of two kinds (section 10 of the specification):

- a **selection** vets particular versions: a reading list the versions you
  read and recommend, a journal issue the versions its editors accepted. Its
  members pin those versions (their *revisions*), and nothing changes unless
  you change it;
- an **archive collection** follows its members whatever their authors add:
  the papers of a group, the objects an archive preserves. Its members pin
  the newest object version, and `osheaf collection update` moves them on. The collection is plain files in a git repository, with a website
listing its members, and is kept with
[opensheaf-py](https://github.com/opensheaf/opensheaf-py) (the `osheaf`
command). For an archive of your own papers, use
[archive-template](https://github.com/opensheaf/archive-template) instead
(an archive can also hold collections).

## 1. Make your copy

Press **Use this template** on GitHub, clone your copy, and install the tools
(Python 3.9 or later):

```
pipx install "opensheaf[validate] @ git+https://github.com/opensheaf/opensheaf-py"
```

## 2. Set it up

Edit [archive.yaml](archive.yaml) (the identifier, name and address of the
collection, and you as its curator), then run once

```
osheaf init . --from archive.yaml
```

This writes `osheaf.json`, the storage root `ocfl/` with an empty curated
collection, the discovery document `opensheaf.json` and the website.

## 3. List the members

Edit [collection.yaml](collection.yaml): the title and description, the
kind, and the members in the order you want, each given by the address of
its archive and the identifier of the object. A reading list is a selection:

```yaml
type: selection
members:
  - {archive: https://mgubi.org/papers/, id: fractional-phi42-mass-gap}
  - {archive: https://mgubi.org/papers/, id: paracontrolled-distributions, revisions: [5]}
```

`revisions` lists the document versions you vet (1, 2, ...); a member
without it is vetted in its current version when first synced, and keeps
that revision. To vet a later version too, add it (`revisions: [5, 6]`) and
sync again: that is a new version of the selection, your act. For an
archive collection write `type: archive`: its members follow their objects
(`follow: latest`), unless you fix one with `version: vN`. A member may be
a document or another collection, in any OpenSheaf archive. Then

```
osheaf collection sync --from collection.yaml
osheaf index
osheaf verify --remote
git add -A && git commit -m "Members" && git push
```

`sync` reads each member's archive (its `opensheaf.json`, the object's
inventory and history), pins the revisions you vet (or, in an archive
collection, the newest object version), checks each pin against the checksum
file the archive publishes, and caches a citation, so that the list stays
readable even if a member's archive disappears. A new version of the
collection is written only when the list or a pin changes.

## 4. Keep it up to date

```
osheaf collection update
osheaf index
```

moves the followed members of an archive collection to the newest versions
of their objects, whatever they hold: a new version, a notice, a
withdrawal (which the website then shows). A selection is never changed by
`update`: it lists the versions of your members that you have not vetted,
and you decide.
`osheaf verify --remote` fetches every member from its archive and checks its
pin; the workflow `verify` does it on every push.

## 5. Publish

On GitHub: **Settings → Pages → Deploy from a branch**, branch `main`, folder
`/ (root)`. The look is in `templates/` (placeholders like `{{title}}`), as in
the archive template.

## A testing ground

`examples/run.sh` builds a member archive from the
[example papers](https://github.com/opensheaf/example-papers) and two
collections with members from it and from a real archive: an archive
collection (followed members, a fixed version, a member that is itself a
collection) and a selection (a reading list). It goes through their
workflows: a new version, followed by the archive collection and only
reported by the selection until the curator vets it; a withdrawal, followed
by one and shown by both; a member that disappears and is reported by
`verify --remote`. Clone the example papers next to this repository and run
`examples/run.sh` (`OFFLINE=1` leaves out the real archive). The workflow
`examples` runs it on every push and every week.

## Journals

`examples/journals.sh` builds two journals from real papers of
[Quantum](https://quantum-journal.org) (volume 7, 2023, CC BY 4.0; an
unofficial demonstration, not made by or for Quantum):

- a journal that **accepts** vetted versions: the authors keep every version
  in their own archive; the journal copies exactly the version it vetted
  (`osheaf accept ... --version v2`) into a document of its own archive, byte
  for byte, with its source and pin, and its issue is a selection of these
  documents, pinning the revisions the editors vetted.
  The authors' later versions change nothing at the journal: a correction is
  an editorial act (a new version of the journal's document, or a notice),
  and enters the issue only when the editors vet it (a new version of the
  issue).
  Only the vetted version needs an open licence, so a paper whose first arXiv
  version is not openly licensed (and could not be mirrored as a whole) can
  be accepted; and the journal still verifies when the authors' archive is
  gone;
- a journal that **repackages** the papers: it deposits its versions of record
  (its typeset PDF, its DOI, its licence, the authors' agreement in
  `object.json`) as documents of its own archive, linked to the authors'
  arXiv versions.

## Licence

This template is dedicated to the public domain under [CC0 1.0](LICENSE). The
member list and the metadata of a collection are placed under CC0, as the
specification asks; the members keep their own licences, and a collection
copies nothing.
