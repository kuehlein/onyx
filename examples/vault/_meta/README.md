# _meta

Vault metadata for the Onyx flashcard system. Files here are NOT indexed as
flashcards (they have no `type: flashcard` frontmatter). Onyx skips this folder.

## Contents

| File | Purpose |
|---|---|
| `tags.md` | Tag index — definitions, conventions, rules for choosing tags |
| `curriculum.md` | Recommended study sequence by domain and tier |
| `conventions.md` | Card writing conventions and section formatting rules |
| `card-creation-skill.md` | Standalone Claude prompt for generating new cards in Neovim |

## Why this folder exists

Without a tag index, tags drift. Two cards that should be linked by the same
tag end up with slightly different spellings (`binary-search` vs `binary_search`
vs `binarySearch`). The graph becomes less connected, quiz filtering becomes
less reliable, and the readiness calculation breaks. Check `tags.md` before
adding any new tag. If a tag you want doesn't exist, add it there first.
