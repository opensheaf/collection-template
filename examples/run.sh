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

step "an archive collection: members from the member archive and from a real archive, followed"
mkdir -p "$C" && cp -R "$HERE/templates" "$C/templates"
osheaf init "$C" --curated --archive-id tag:example.org,2026:reading --name "A reading list" \
  --base-url https://example.org/reading/ --curator "Example, Ada"
{
  echo "title: The papers of a group"
  echo "description: Members from two archives, followed as they grow, in the curator's order."
  echo "type: archive"
  echo "members:"
  echo "  - {archive: $M, id: random-walks}                        # followed"
  echo "  - {archive: $M, id: heat-notes, version: v1}             # a fixed version"
  echo "  - {archive: $M, id: kobayashi-park}                      # followed, withdrawn later"
  echo "  - {archive: $M, id: collection-main}                     # a collection as a member"
  if [ -z "${OFFLINE:-}" ]; then
    echo "  - {archive: https://mgubi.org/papers/, id: fractional-phi42-mass-gap}"
    echo "  - {archive: https://mgubi.org/papers/, id: paracontrolled-distributions, version: v2}"
  fi
} > "$W/group.yaml"
osheaf --root "$C" collection sync --from "$W/group.yaml"         # the main collection
osheaf --root "$C" index
osheaf --root "$C" verify --remote

step "a selection: a reading list vetting particular versions"
{
  echo "title: A reading list"
  echo "description: The versions the curator read and recommends."
  echo "type: selection"
  echo "members:"
  echo "  - {archive: $M, id: random-walks, revisions: [1]}        # the version read"
  echo "  - {archive: $M, id: heat-notes}                          # vetted in its current version"
  echo "  - {archive: $M, id: kobayashi-park, revisions: [1]}"
  if [ -z "${OFFLINE:-}" ]; then
    echo "  - {archive: https://mgubi.org/papers/, id: paracontrolled-distributions, revisions: [5]}"
  fi
} > "$W/reading.yaml"
osheaf --root "$C" collection sync reading --from "$W/reading.yaml"  # a second collection, named
osheaf --root "$C" index
osheaf --root "$C" verify --remote

step "a new version in the member archive: the archive collection follows it, the selection does not"
osheaf --root "$M" deposit random-walks "$EX/papers/random-walks/v2/paper.tex" \
  --pdf "$EX/papers/random-walks/v2/paper.pdf" --title "Random walks on a fictitious lattice" \
  --author "Example, Ada" --changes "A new version, to be followed by the collection."
osheaf --root "$M" collect && osheaf --root "$M" index
osheaf --root "$C" collection update && osheaf --root "$C" collection update reading && osheaf --root "$C" index
osheaf --root "$C" verify --remote

step "the curator reads the new version and vets it too: a new version of the selection"
sed -i.bak 's/id: random-walks, revisions: \[1\]/id: random-walks, revisions: [1, 2]/' "$W/reading.yaml"
osheaf --root "$C" collection sync reading --from "$W/reading.yaml"
osheaf --root "$C" index && osheaf --root "$C" verify --remote

step "a member is withdrawn: the archive collection follows the withdrawal; the selection keeps its revision, and both show the withdrawal"
osheaf --root "$M" withdraw kobayashi-park --reason "An invented withdrawal, to try collections."
osheaf --root "$C" collection update && osheaf --root "$C" collection update reading && osheaf --root "$C" index
osheaf --root "$C" verify --remote

step "updating again changes nothing"
osheaf --root "$C" collection update && osheaf --root "$C" collection update reading

step "a member disappears from its archive: verify --remote reports it"
mv "$M/ocfl/heat-notes" "$W/heat-notes.removed"
if osheaf --root "$C" verify --remote; then echo "expected an error"; exit 1; fi
mv "$W/heat-notes.removed" "$M/ocfl/heat-notes"
osheaf --root "$C" verify --remote

step "the website of the collection"
osheaf --root "$C" index
printf '\nThe collection is in %s (open %s/index.html).\n' "$C" "$C"
