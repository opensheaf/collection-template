#!/usr/bin/env bash
# Two journals, as OpenSheaf archives, built from real papers of Quantum
# (quantum-journal.org, volume 7, 2023; CC BY 4.0) in the example papers.
# An unofficial demonstration: not made by or for Quantum.
#
#  1. A journal that ACCEPTS a vetted version: the authors keep their papers,
#     with all their versions, in their own archive (here imported from arXiv).
#     The journal copies exactly the version it vetted (osheaf accept) into a
#     document of its own archive, byte for byte, recording its source and pin;
#     its issue is a selection of these documents, pinning the revisions the
#     editors vetted. The authors' later
#     versions change nothing at the journal: a correction is an editorial
#     act, a new version of the journal's document made by the editors. Only
#     the vetted version needs an open licence (or the authors' agreement), so
#     a paper whose first arXiv version is not openly licensed can be accepted.
#  2. A journal that REPACKAGES the papers: it deposits its own version of
#     record (its typeset PDF, its DOI, its licence, the authors' agreement)
#     as documents of its own archive, linked to the authors' arXiv versions.
#
#   examples/journals.sh [EXAMPLE-PAPERS-FOLDER] [WORK-FOLDER]
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
EX=$(cd "${1:-$HERE/../example-papers}" && pwd)
W=${2:-$(mktemp -d)}
A=$W/authors J=$W/journal-accept V=$W/journal-vor
step() { printf '\n== %s\n' "$*"; }

step "the authors' archive: the Quantum papers from arXiv (every version CC BY), and a paper whose v1 is not openly licensed"
osheaf init "$A" --archive-id tag:example.org,2026:authors --name "The authors' archive" \
  --base-url https://example.org/authors/ --curator "Example, Ada"
osheaf --root "$A" arxiv import "$EX/journal-quantum"
osheaf --root "$A" arxiv import "$EX/arxiv-downloads" 0000.00001
osheaf --root "$A" collect && osheaf --root "$A" index

step "1. a journal that accepts vetted versions: v2 of each paper, copied into documents of its own"
osheaf init "$J" --archive-id tag:example.org,2026:journal-accept \
  --name "An accepting journal (unofficial demonstration with papers of Quantum 7)" \
  --base-url https://example.org/journal-accept/ --curator "Example, Ada"
for p in hirche-network-discrimination singal-stabiliser-codes peters-generalization-overfitting; do
  osheaf --root "$J" accept "$A" "$p" --version v2 --stage VoR --type JournalArticle \
    --agreement "the journal's publication terms (CC BY 4.0)"
done

step "a paper whose v1 is under arXiv's licence: a full mirror is refused, but its vetted v2 is CC BY and can be accepted"
if osheaf --root "$J" mirror "$A" fictitious-walks; then echo "expected a refusal"; exit 1; fi
osheaf --root "$J" accept "$A" fictitious-walks --version v2 --stage VoR --type JournalArticle
osheaf --root "$J" collect

step "the issue: a selection of the accepted copies, each vetted in its first version"
issue() {
  echo "title: Volume 7, issue 1"
  echo "description: The papers accepted, in the versions the editors vetted."
  echo "type: selection"
  echo "members:"
  echo "  - {archive: ., id: hirche-network-discrimination, revisions: [$1]}"
  echo "  - {archive: ., id: singal-stabiliser-codes, revisions: [1]}"
  echo "  - {archive: ., id: peters-generalization-overfitting, revisions: [1]}"
  echo "  - {archive: ., id: fictitious-walks, revisions: [1]}"
}
issue 1 > "$W/issue.yaml"
osheaf --root "$J" collection sync issue-1 --from "$W/issue.yaml"
osheaf --root "$J" index
osheaf --root "$J" verify --remote      # also compares the accepted copies with their sources

step "the authors post a new version: the journal's documents do not change"
osheaf --root "$A" deposit hirche-network-discrimination "$EX/papers/random-walks/v2/paper.tex" \
  --pdf "$EX/papers/random-walks/v2/paper.pdf" --title "Quantum Network Discrimination" \
  --author "Hirche, Christoph" --changes "A later version by the author (invented, for the demonstration)."
osheaf --root "$A" collect && osheaf --root "$A" index
osheaf --root "$J" collect && osheaf --root "$J" collection update issue-1

step "the editors correct a paper: an editorial act, a new version of the journal's document"
osheaf --root "$J" notice singal-stabiliser-codes --about 1 --text "An invented erratum, issued by the editors."
osheaf --root "$J" accept "$A" hirche-network-discrimination --version v3 \
  --changes "Corrected by the editors: the author's version v3 replaces v2 (an invented correction)."
osheaf --root "$J" collect
osheaf --root "$J" collection update issue-1      # reports the correction, does not vet it
issue "1, 2" > "$W/issue.yaml"                    # the editors vet it: a new version of the issue
osheaf --root "$J" collection sync issue-1 --from "$W/issue.yaml"
osheaf --root "$J" index && osheaf --root "$J" verify --remote

step "the authors' archive disappears: the journal's documents are its own, and still verify"
mv "$A" "$W/authors.gone"
osheaf --root "$J" verify
mv "$W/authors.gone" "$A"

step "2. a journal that repackages: its versions of record, with its licence and the authors' agreement"
osheaf init "$V" --archive-id tag:example.org,2026:journal-vor \
  --name "A publishing journal (unofficial demonstration with papers of Quantum 7)" \
  --base-url https://example.org/journal-vor/ --curator "Example, Ada"
osheaf --root "$V" deposit --from "$EX/deposits/quantum-vor.yaml"
osheaf --root "$V" collect && osheaf --root "$V" index
osheaf --root "$V" verify

printf '\nThe accepting journal is in %s, the publishing journal in %s.\n' "$J" "$V"
