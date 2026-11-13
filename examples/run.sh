#!/usr/bin/env bash
# The testing ground of the collection template: builds a member archive from
# the example papers (https://github.com/opensheaf/example-papers), then a
# curated collection with members from it and from a real archive
# (https://mgubi.org/papers/), and goes through the workflows of collections,
# also the unusual ones. Nothing in this repository is changed.
#
#   examples/run.sh [EXAMPLE-PAPERS-FOLDER] [WORK-FOLDER]
#
# Set OFFLINE=1 to leave out the real archive.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
EX=$(cd "${1:-$HERE/../example-papers}" && pwd)
W=${2:-$(mktemp -d)}
M=$W/member-archive C=$W/collection
step() { printf '\n== %s\n' "$*"; }

step "a member archive, built from the example papers"
osheaf init "$M" --archive-id tag:example.org,2026:member --name "Example member archive" \
  --base-url https://example.org/member/ --curator "Example, Ada"
osheaf --root "$M" deposit --from "$EX/deposits/random-walks.yaml"
osheaf --root "$M" deposit --from "$EX/deposits/heat-notes.yaml"
osheaf --root "$M" arxiv import "$EX/arxiv-real"
osheaf --root "$M" collect && osheaf --root "$M" index

step "a curated collection: members from the member archive and from a real archive"
mkdir -p "$C" && cp -R "$HERE/templates" "$C/templates"
osheaf init "$C" --curated --archive-id tag:example.org,2026:reading --name "A reading list" \
  --base-url https://example.org/reading/ --curator "Example, Ada"
{
  echo "title: A reading list"
  echo "description: Members from two archives, in the curator's order."
  echo "members:"
  echo "  - {archive: $M, id: random-walks}                        # followed"
  echo "  - {archive: $M, id: heat-notes, version: v1}             # a fixed version"
  echo "  - {archive: $M, id: kobayashi-park}                      # followed, withdrawn later"
  echo "  - {archive: $M, id: collection-main}                     # a collection as a member"
  if [ -z "${OFFLINE:-}" ]; then
    echo "  - {archive: https://mgubi.org/papers/, id: fractional-phi42-mass-gap}"
    echo "  - {archive: https://mgubi.org/papers/, id: paracontrolled-distributions, version: v2}"
  fi
} > "$W/collection.yaml"
osheaf --root "$C" collection sync --from "$W/collection.yaml"
osheaf --root "$C" index
osheaf --root "$C" verify --remote

step "a new version in the member archive: update follows it (the fixed version stays)"
osheaf --root "$M" deposit random-walks "$EX/papers/random-walks/v2/paper.tex" \
  --pdf "$EX/papers/random-walks/v2/paper.pdf" --title "Random walks on a fictitious lattice" \
  --author "Example, Ada" --changes "A new version, to be followed by the collection."
osheaf --root "$M" collect && osheaf --root "$M" index
osheaf --root "$C" collection update && osheaf --root "$C" index
osheaf --root "$C" verify --remote

step "a followed member is withdrawn: update keeps its pin and says so"
osheaf --root "$M" withdraw kobayashi-park --reason "An invented withdrawal, to try collections."
osheaf --root "$C" collection update && osheaf --root "$C" index
osheaf --root "$C" verify --remote

step "updating again changes nothing"
osheaf --root "$C" collection update

step "a member disappears from its archive: verify --remote reports it"
mv "$M/ocfl/heat-notes" "$W/heat-notes.removed"
if osheaf --root "$C" verify --remote; then echo "expected an error"; exit 1; fi
mv "$W/heat-notes.removed" "$M/ocfl/heat-notes"
osheaf --root "$C" verify --remote

step "the website of the collection"
osheaf --root "$C" index
printf '\nThe collection is in %s (open %s/index.html).\n' "$C" "$C"
