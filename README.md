# An OpenSheaf collection

> [!WARNING]
> **Draft.** OpenSheaf 0.1 is a draft specification. Until version 1.0, any
> revision may change the format in incompatible ways (one already did:
> `provenance.json` became `object.json`). Archives and collections made now
> may have to be rebuilt or migrated, and the tools follow the latest draft.
> Do not rely on it yet for anything you cannot redo.

A template for a curated collection of papers kept in other archives: a
reading list, the papers of a group, a seminar, a special issue. Nothing is
copied: each member is an object of an [OpenSheaf](https://opensheaf.org)
archive, pinned by the SHA-512 digest of the inventory of the version you
choose, so that the collection fixes exactly what it lists, and anyone can
check it. The collection is plain files in a git repository, with a website
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

Edit [collection.yaml](collection.yaml): the title and description, and the
members in the order you want, each given by the address of its archive and
the identifier of the object:

```yaml
members:
  - {archive: https://mgubi.org/papers/, id: fractional-phi42-mass-gap}
  - {archive: https://mgubi.org/papers/, id: paracontrolled-distributions, version: v5}
```

A member without `version` is pinned to the current version of its document
and followed (`follow: latest`); with `version`, that version stays. A member
may be a document or another collection, in any OpenSheaf archive. Then

```
osheaf collection sync --from collection.yaml
osheaf index
osheaf verify --remote
git add -A && git commit -m "Members" && git push
```

`sync` reads each member's archive (its `opensheaf.json`, the object's
inventory and history), pins the current version, checks the pin against the
checksum file the archive publishes, and caches a citation, so that the list
stays readable even if a member's archive disappears. A new version of the
collection is written only when the list or a pin changes.

## 4. Keep it up to date

```
osheaf collection update
osheaf index
```

moves followed members to the current versions of their documents. A member
that its archive has withdrawn keeps its pin, and the tool says so.
`osheaf verify --remote` fetches every member from its archive and checks its
pin; the workflow `verify` does it on every push.

## 5. Publish

On GitHub: **Settings → Pages → Deploy from a branch**, branch `main`, folder
`/ (root)`. The look is in `templates/` (placeholders like `{{title}}`), as in
the archive template.

## A testing ground

`examples/run.sh` builds a member archive from the
[example papers](https://github.com/opensheaf/example-papers) and a curated
collection with members from it and from a real archive, and goes through the
workflows of collections: a fixed version and followed ones, a member that is
itself a collection, a new version followed by `update`, a withdrawn member
whose pin is kept, a member that disappears and is reported by
`verify --remote`. Clone the example papers next to this repository and run
`examples/run.sh` (`OFFLINE=1` leaves out the real archive). The workflow
`examples` runs it on every push and every week.

## Licence

This template is dedicated to the public domain under [CC0 1.0](LICENSE). The
member list and the metadata of a collection are placed under CC0, as the
specification asks; the members keep their own licences, and a collection
copies nothing.
