# Card

> See [index.md](index.md) for the model + glossary. Open questions carry a **Rec:**.

**Purpose.** A multi-modal widget for one card (a vault file) shown across contexts.
**Scope.** A card is a vault file; it can belong to several decks (lenses) at once.
**Personas.** All.
**Reached from.** Browse (tap a card) · authoring · a stub from Browse's broken-links view.

## Modes
- **View** — read the whole file.
- **Study / testing** — the Anki-style front/back. A study "card" is the **whole file or a
  parsed subset** (a section), per the deck's parsing rules; after flipping, you can see the
  whole file.
- **Authoring** — create/edit: a plain editor (self-edit), an **AI editor** (chat: "make a card
  about X" or "update this card..." informed by the deck's authoring skill), and later a file uploader / camera for AI
  extraction. [MVP: editor + light AI chat; upload/camera later]
- **Stub** — a placeholder for a **broken link**: a defaulted title (from the link) + a
  **References** section listing everything that links to it, plus the authoring affordance to
  fill it in.

## What it does
- **Collapsible sections.** Some open/closed by default; sections that reach a retention
  threshold **collapse by default with a "mastered" badge.**
- **Visual indicators** for which sections become study cards (what the parsing rules will
  extract), shown when viewing the whole file — likely each study-unit is itself a collapsible
  section.

## Open questions → recommendations
- **Where do open/closed defaults + "what is a section" live — vault/deck settings, or card
  frontmatter?**
  **Rec.** Both, layered: the deck's **parsing rules** set the defaults (what's a section, which
  open by default); a card's **frontmatter** can override per-card. Mastered-section
  auto-collapse is engine behavior, not config.
  **Status.** Accepted
- **Does authoring here need skill selection / creating new skills?**
  **Rec.** Non-MVP. Default to the **deck's** authoring skill; expose picking/creating skills
  later, only if users ask.
  **Status.** Accepted
- **How multi-modal should one widget be?**
  **Rec.** Share **layout + section rendering** across view/study/authoring/stub, differing only in
  affordances — so behavior stays consistent and we avoid four half-overlapping screens.
  **Status.** Accepted — **realized as a shared component LAYER, not a single mode-param widget**
  ([ADR-0012](../adr/0012-card-model-shared-components.md)). The scope pass found the four modes are too
  disjoint below the shared chrome for one `CardView(mode)` container (a `switch(mode)` over disjoint
  bodies is its own mode-branch smell, and it would funnel the high-risk study grade paths through shared
  code). Instead, shared components — `CardScaffold` · `CardSection` (the single section renderer) ·
  `CardHead` · `CardMetaChip` · `CardLinks` · `sectionExpandDefault` — are composed by each thin surface;
  **study (learn/quiz) keep their own screens + schedulers** and merely *adopt* `CardSection`. This
  satisfies "share layout + section rendering, differ only in affordances" via composition.
- **How to handle modifying cards that have already been learned/tested?**
  **Rec.** Default: **keep the FSRS history** — the schedule is tied to the card/section identity,
  not its exact text, so fixing a typo or clarifying doesn't reset progress. When an edit
  **materially changes what's tested** (the answer itself changed), the old schedule is
  misleading → offer a per-edit choice: *keep schedule* vs *reset this card/section*, optionally
  routing it through a light re-verify (mirroring how pulled/updated cards re-enter the draft
  gate). Never silently reset.
  **Status.** Accepted.
- **How to handle sections that should not be tested?** - I think we hardcode some card sections to not be studied (e.g., references), but this should be up to the user as they may structure cards differently. Can the query lens for deck building be granular enough to include or exclude parts of a card? Likely non-MVP unless easy. This can be ignored if too challenging in favor of removing specific cards or sections from the deck at a per-deck settings level.
  **Rec.** Two layered mechanisms, both already partly in the engine: a **per-deck `neverQuizzed`
  set** (e.g. `References`, `Sources`) in the deck's parse rules — the default blocklist,
  user-editable — and a **per-card frontmatter** override (mark a section `quizzable: false`).
  That handles "everyone structures cards differently" without new machinery. Making the **query
  lens** exclude *parts of a card* is more than a lens does (a lens selects cards, not sub-card
  slices) → **skip**; the neverQuizzed + frontmatter path is the clean MVP, with per-deck section
  exclusion as the fallback you noted.
  **Status.** Accepted (query-lens sub-card granularity dropped).

## Cross-refs
[browse](browse.md) (entry + stubs) · [deck_creation](deck_creation.md) (authoring) ·
[settings](settings.md) (parsing rules) · older: `card-schema.md`, `#20` (unresolved links),
`#28` (in-app create).
