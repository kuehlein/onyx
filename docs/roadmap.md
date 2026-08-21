# Onyx — Roadmap

## MVP (Phase 1)

Goal: validate the core study loop and deliver a genuinely useful interview
prep tool from day one.

### Screens
- **Onboarding** — vault folder picker; API key entry
- **Dashboard** — cards due today, readiness estimate per domain, study streak
- **Browse** — searchable card list; filter by tag, domain, tier, card type
- **Card detail** — rendered markdown; related cards; "Ask Claude" button
- **Quiz session** — concept cards (section-based) + interview questions (problem-first); 1–4 grade; practice redirect
- **Settings** — vault path, API key, quiz preferences, section blocklist

### Core features

**Vault & indexing**
- [ ] Parse `type: flashcard` and `type: interview-question` files; skip `_meta/`
- [ ] Extract frontmatter: id, type, tags, tiers, concepts, practice_url, source
- [ ] Section discovery: H2 sections minus configurable blocklist; `quiz` override
- [ ] Wikilink indexing → card_links cache in SQLite
- [ ] card_cache table populated on index (title, tags, tiers, type, practice_url)
- [ ] Cards without valid `id` skipped; count shown in Settings

**SRS & quiz**
- [ ] FSRS v4 per `(card_id, section_slug)` pair
- [ ] Concept card quiz: front = "Title — Section", back = section content
- [ ] Interview question quiz: front = problem statement (pre-H2), reveal = Approach section
- [ ] Post-grade practice redirect for interview questions (grade ≥ 3 → skippable "Open NeetCode" prompt)
- [ ] Interleaving: post-selection reorder by primary domain tag within session
- [ ] Grading UI: 1 (Again) / 2 (Hard) / 3 (Good) / 4 (Easy)
- [ ] Session summary: cards reviewed, grade distribution, new cards introduced

**Browse & search**
- [ ] Full-text search over card titles and body
- [ ] Filter by: tag, domain, tier, card type, difficulty (interview questions), frequency
- [ ] Card detail: render markdown, show related cards, show concept links (interview questions)

**AI**
- [ ] "Ask Claude" on card detail — sends full card markdown + user question; renders response
- [ ] API key stored in iOS Keychain via `flutter_secure_storage`

**Readiness dashboard**
- [ ] Per-domain readiness: coverage (cards created / planned per tier) × avg FSRS stability
- [ ] Domains shown: DS&A, System Design, Blockchain, Lang/Frameworks
- [ ] Tiers 1–2 weighted more heavily in the score

**Infrastructure**
- [ ] Security-scoped bookmark for vault folder access
- [ ] `url_launcher` for practice redirect URLs
- [ ] Interleaving scheduler

### Out of scope for MVP
- URL content fetching / AI reading comprehension
- Weak area AI report
- Card creation from app
- Detailed history charts
- Multiple vault folders

---

## Phase 2

**Interview question library**
- Create NeetCode 150 as interview-question cards, grouped by pattern
- System design question set from Alex Xu Vol 1 (core 10–15 problems)
- Blockchain question set (curated)
- Filter quiz by question source (NeetCode 150, Blind 75, etc.)

**Session customization**
- Quiz by: tag, domain, tier, card type, difficulty, frequency
- Session modes: due-only | new-only | mixed | interview simulation (questions only)
- Card count limit per session

**Study quality**
- Vault refresh: detect added/removed/modified cards; update SQLite incrementally
- Weak area surfacing: cards/domains with consistently low FSRS grades on dashboard
- Unresolved link view: wikilinks with no matching card (gaps to fill)
- Retention rate by tag and domain

**URL resource scanning (AI reading comprehension)**
- User selects a `## Resources` URL from a card
- App fetches URL content, strips to plaintext
- Claude receives the text as context; user can ask questions about it
- Claude generates 3–5 comprehension questions from the content; user answers and self-grades
- Activity logged; treated as a study session for that card's domain

Design note: requires `html` or similar package for HTML stripping. The Claude
context window comfortably fits most technical articles. For very long sources
(book chapters), truncate to first N tokens with a note.

**Card creation from app**
- Write new `.md` files into the vault folder via security-scoped bookmark write access
- Templates for each card type (flashcard, interview-question, lang-framework)

---

## Phase 3 — AI Study Assistant

- **Weak area report** — serialize SRS state + activity log → Claude → actionable summary
- **Study session suggestions** — AI recommends tag/domain focus given stated goal ("interview in 3 days")
- **Contextual hints** — during quiz, optional hint from Claude that guides without spoiling
- **Interview readiness assessment** — Claude analyzes coverage, stability, and weak areas across all domains and gives a qualitative interview readiness verdict

---

## Future / Backlog

- Android support
- macOS adaptive layout (same codebase)
- Cloze deletion card type
- Multiple vault folder support
- SRS state export / import
- Design Patterns (GoF) card library — lower interview frequency but high general SWE value
- Offline AI via on-device model
