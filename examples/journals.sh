#!/usr/bin/env bash
# Two journals, as OpenSheaf archives, built from real papers of Quantum
# (quantum-journal.org, volume 7, 2023; CC BY 4.0) in the example papers.
# An unofficial demonstration: not made by or for Quantum.
#
#  1. A journal that MIRRORS the papers: the authors keep their papers in their
#     own archive (here imported from arXiv); the journal's issue is a curated
#     collection that copies each paper (every version, byte for byte) into the
#     journal's archive, which the CC BY licence of every version allows. A paper
#     whose first version is not openly licensed cannot be mirrored: the journal
#     only references it. When the authors' archive disappears, the issue is
#     still checked and served from the journal's copies.
#  2. A journal that REPACKAGES the papers: it deposits its own version of
#     record (its typeset PDF, its DOI, its licence, the authors' agreement)
#     as documents of its own archive, linked to the authors' arXiv versions.
#
#   examples/journals.sh [EXAMPLE-PAPERS-FOLDER] [WORK-FOLDER]
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
EX=$(cd "${1:-$HERE/../example-papers}" && pwd)
W=${2:-$(mktemp -d)}
A=$W/authors J=$W/journal-mirror V=$W/journal-vor
step() { printf '\n== %s\n' "$*"; }

step "the authors' archive: the Quantum papers from arXiv (every version CC BY), and a paper whose v1 is not openly licensed"
osheaf init "$A" --archive-id tag:example.org,2026:authors --name "The authors' archive" \
  --base-url https://example.org/authors/ --curator "Example, Ada"
osheaf --root "$A" arxiv import "$EX/journal-quantum"
osheaf --root "$A" arxiv import "$EX/arxiv-downloads" 0000.00001
osheaf --root "$A" collect && osheaf --root "$A" index

step "1. a journal that mirrors: an issue as a curated collection, its papers copied into the journal's archive"
mkdir -p "$J" && cp -R "$HERE/templates" "$J/templates"
osheaf init "$J" --curated --archive-id tag:example.org,2026:journal-mirror \
  --name "A mirroring journal (unofficial demonstration with papers of Quantum 7)" \
  --base-url https://example.org/journal-mirror/ --curator "Example, Ada"
cat > "$W/issue.yaml" <<YAML
title: "Volume 7 (2023), a selection"
description: "Papers of Quantum, volume 7 (2023), mirrored from their authors' archive under CC BY 4.0. An unofficial demonstration, not made by or for Quantum."
members:
  - {archive: $A, id: hirche-network-discrimination, mirror: yes}
  - {archive: $A, id: singal-stabiliser-codes, mirror: yes}
  - {archive: $A, id: peters-generalization-overfitting, mirror: yes}
YAML
osheaf --root "$J" collection sync --from "$W/issue.yaml"

step "a paper whose v1 is under arXiv's licence cannot be mirrored (the tool refuses) ..."
if osheaf --root "$J" mirror "$A" fictitious-walks; then echo "expected a refusal"; exit 1; fi
step "... so the journal only references it: a pin needs no permission"
cat >> "$W/issue.yaml" <<YAML
  - {archive: $A, id: fictitious-walks}
YAML
osheaf --root "$J" collection sync --from "$W/issue.yaml"
osheaf --root "$J" index
osheaf --root "$J" verify --remote

step "the authors' archive disappears: the mirrored papers are checked on the journal's copies, the reference is reported"
mv "$A" "$W/authors.gone"
if osheaf --root "$J" verify --remote; then echo "expected the reference to be reported"; exit 1; fi
osheaf --root "$J" index
mv "$W/authors.gone" "$A"
osheaf --root "$J" verify --remote

step "2. a journal that repackages: its versions of record, with its licence and the authors' agreement"
osheaf init "$V" --archive-id tag:example.org,2026:journal-vor \
  --name "A publishing journal (unofficial demonstration with papers of Quantum 7)" \
  --base-url https://example.org/journal-vor/ --curator "Example, Ada"
osheaf --root "$V" deposit --from "$EX/deposits/quantum-vor.yaml"
osheaf --root "$V" collect && osheaf --root "$V" index
osheaf --root "$V" verify

printf '\nThe mirroring journal is in %s, the publishing journal in %s.\n' "$J" "$V"
