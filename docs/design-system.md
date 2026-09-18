# Onyx Design System

The buildable visual-language + widget-library companion to `docs/ux-vision.md`. This is the token/widget-library home that ux-vision §8 references but that never existed until now. It is **decisive**: where the source research or the parts disagreed, one value or structure was chosen and the alternatives were cut. Every number below is either measured against WCAG or grounded in a cited principle.

> **Status of the codebase.** The current theme (`lib/app/theme.dart`) is a bare 24-line `ColorScheme.fromSeed(0xFF6B46C1)` with no component themes, no `TextTheme`, no `ThemeExtension`. Semantic status colors live outside the scheme as raw consts in `lib/shared/status_colors.dart`, duplicated again in `callout.dart` and `log_solve_sheet.dart`. Screens already speak idiomatic M3 (surface-container roles, `onSurfaceVariant`). So this system is **additive**: two `ThemeExtension`s + component themes + a `TextTheme`, adopted screen-by-screen, no big-bang rewrite.

---

## 1. Design principles

1. **Calm, dark-locked.** One dark theme, off-white on dark-gray. Never `#FFF` on `#000` (halation, worst for astigmatic readers — [Smashing: Inclusive Dark Mode](https://www.smashingmagazine.com/2025/04/inclusive-dark-mode-designing-accessible-dark-themes/)). No light theme, no system-toggle, no theme row anywhere. Low chroma is the primary lever for a low-stimulation study environment.
2. **One accent hue.** Violet (seed `#6B46C1`, desaturated ~25% for dark). Hierarchy comes from **weight + opacity, never a second hue** (avoids the 6-color-overload finding — dataviz memory). Status colors are the *only* sanctioned exception, and only because they encode meaning — and they always carry a redundant shape+label.
3. **Honest, uncertainty-first.** Show a readiness **band** that widens with thin evidence; weakest-link caps readiness; say "can't judge yet" / "not enough data yet," never a fabricated 0% or a number that can't fall. No cross-goal aggregate (averaging templates is dishonest). Readiness must be able to *fall*.
4. **No gamified chrome.** No points/XP, badges, levels, leaderboards, **streaks**, streak-freeze/loss-aversion, confetti, trophies, or social mechanics ([gamification-stance](../MEMORY); ux-vision L16/L31/L217). Competence is signaled by honest completion + honest readiness delta. **"Done" = the absence of the Filled button, not a reward animation.**
5. **M3-customized, not fought.** Build on Material 3 (`useMaterial3`, default since Flutter 3.16). Customize `ColorScheme` roles, add a `TextTheme` and component themes, carry the rest in two `ThemeExtension`s. Never hardcode a hex/radius/gap in a widget.
6. **Bars > rings** (Cleveland–McGill). Bars for comparison, sparklines for trends, a shaded band + verbal qualifier for forecasts. Exactly **one** ring in the whole app: a single completion %. No radial gauges for comparison.
7. **Accessible by construction.** Every status pairs **color + shape + number + Semantics label** — never color alone ([WebAIM](https://webaim.org/resources/contrastchecker/)). Body/status text ≥ 4.5:1; large text and non-text UI ≥ 3:1; 48×48 touch targets; respect OS text-scaling and Reduce-Motion.
8. **Calm restraint / critical-few.** 3–5 items above the fold, one hero metric per surface, single implementations (one `SharedBudgetBar`, one adjust-mix editor), tonal elevation over shadows, short + standard motion. Progressive disclosure: teaching sections expanded, supplementary collapsed.

---

## 2. Token system

Two tiers. **Primitive** raw values live in one private file and are consumed *only* by the semantic layer. **Semantic** = M3 `ColorScheme` roles + two `ThemeExtension`s (`OnyxColors`, `OnyxTokens`). No component-token tier (over-engineering for a single-brand, single-dev, dark-locked app — [uxpin](https://www.uxpin.com/studio/blog/what-are-design-tokens/)).

> **Token pipeline — none now, but keep the door open (revised 2026-09-17, post-research).** A DTCG-JSON / Style-Dictionary codegen pipeline pays off only with Figma handoff, multi-brand, or **sharing one brand across a non-Flutter platform** — and the last is a *when-not-if* for Onyx (the eventual marketing site + interactive deck repository should **not** be Flutter Web: canvas rendering ⇒ no SEO, no link-preview share cards, no SSR → plan Next.js/Astro). So **don't build a pipeline now** (Style Dictionary's Flutter output is flat consts, not `ThemeData`, so it couldn't own the semantic layer anyway) — but pay ~30 min of insurance so a later migration is mechanical: keep `_palette.dart` a **flat, alias-free, pure-data table grouped to mirror the DTCG token types** (`color` / `dimension` / `number` / `duration`), the *sole* home of raw values, with `OnyxTokens.standard` **sourcing its numbers from it** (not re-literalling them). DTCG hit a stable v1 (v2025.10, Oct 2025), so the target format is settled; a later generator (`tokensync` / `design_tokens_builder` / a small `build_runner`) would emit the Dart primitives + `tokens.css`/`.ts` for the web while the hand-written semantic Dart (`onyxDarkScheme()`, the two extensions) stays put. `[research 2026-09-17]` **Built as Step 0** (`lib/shared/design/`).

### 2.1 Color — primitive ramps

Off-black base `#121417` (not `#000` — halation; a barely-perceptible ~265° violet bias for "onyx"). Each surface step ≈ +3–5% L\*, giving legible **tonal elevation without shadows** ([M3 elevation](https://m3.material.io/styles/elevation/applying-elevation) — depth = lighter surface).

**Neutral surface ramp**

| Primitive | Hex | Role it feeds | Used for |
|---|---|---|---|
| `_n05` | `#0E1013` | `surfaceDim` / scrim edge | deepest |
| `_n10` | `#121417` | `surface` | app background, session bg |
| `_n15` | `#171A1F` | `surfaceContainerLowest` | — |
| `_n20` | `#1C1F25` | `surfaceContainerLow` | **resting cards**, lane/flow rows, tiles, code block |
| `_n25` | `#22262D` | `surfaceContainer` | default card, nav bar |
| `_n30` | `#292E36` | `surfaceContainerHigh` | raised card, ring track, skeleton base |
| `_n35` | `#323841` | `surfaceContainerHighest` | sheets, dialogs, menus |
| `_n45` | `#3C424C` | `outlineVariant` | hairlines |
| `_n60` | `#565D68` | `outline` | borders, disabled edge |

**Off-white text ramp** (never `#FFF`). Contrast measured on `_n10 #121417`.

| Primitive | Hex | Contrast on `_n10` | Role | Used for |
|---|---|---|---|---|
| `_ink90` | `#E7E9EC` | ~13.5:1 | `onSurface` | primary text, headings, card term |
| `_ink70` | `#AEB4BD` | ~7.2:1 | `onSurfaceVariant` | secondary text, metadata |
| `_ink55` | `#8A9099` | ~5.7:1 | dim informational (see below) | "not scheduled", "paused", "No data" |

> **Critique fix (F2/F3).** The earlier `0.38`-opacity dim tier and `_ink45 #767C86` (~4.4:1) both **fail AA** for real state text ("not scheduled today," "paused" are meaningful, not decorative — the WCAG disabled-text exemption does not apply, and constraint 13 "segment-always honesty" is undercut by a sub-legible label). Honest state text uses **`_ink55` (5.7:1)** paired with its glyph (`○`, `⏸`). The `0.38` alpha is reserved for **non-informational decoration only** (hairline ticks, disabled control chrome).

**Accent (violet) ramp** — ONE hue, pulled toward the 200–300 tonal band and desaturated ~25% ([devpalettes](https://devpalettes.com/blog/dark-mode-color-guide/)).

| Primitive | Hex | Contrast on `_n10` | Role | Used for |
|---|---|---|---|---|
| `_v80` | `#C9B8F2` | ~9.8:1 | `primary` | accent text/icons, Filled bg, bar/ring fill |
| `_v70` | `#B39DEB` | ~7.8:1 | hover/pressed accent | — |
| `_v40` | `#5B4A8C` | — | `primaryContainer` | tonal-button fill |
| `_onV` | `#231737` | ~9.3:1 on `_v80` | `onPrimary` | text on Filled button |
| `_onVC`| `#E4DAFB` | — | `onPrimaryContainer` | text on tonal button |

> **Filled button** = light violet `_v80` fill with dark `_onV` label. On a dark bg, a light fill + dark text reads far more strongly than a dark fill + light text. One Filled per surface.

**Status ramp** (meaning-only; each MUST ship with icon + shape + label). Contrast on `_n10`.

| Primitive | Hex | Contrast | Meaning | Paired glyph |
|---|---|---|---|---|
| `good` | `#4CC38A` | ~8.3:1 | good / holding / pass / high-confidence | ✓ |
| `warn` | `#E3B341` | ~9.9:1 | developing / shaky / medium-confidence | ◐ / ! |
| `bad` | `#F0757C` | ~7.1:1 | weak / lapsing / low-confidence | ▲ / × |
| `info` | `#5AA7E6` | ~6.9:1 | neutral progress / FSRS "Easy" | ◆ |
| `muted`| `#8A9099` | ~5.7:1 | no data / untouched / paused | ○ |

> **No `flame`, no `dataInk`.** `flame #F2792B` (the streak color) is **deleted, not retokenized** — see §4.13. `dataInk` is dropped (it duplicated `onSurfaceVariant`, its only proposed consumer; charts use `onSurfaceVariant`). `error` reuses `bad` so "error" and "weak" don't diverge into two reds.

### 2.2 Typography scale

Two systems: **chrome** (dense, scannable — M3 `TextTheme`) and **reading** (long-form study passages — two extra roles). The spec's one reading requirement is **body ~16px / line-height 1.5 / measure ~66ch** (ux-vision L325) — so reading body is **16px**, not 18 (critique B1). Weight tops out at **600** (semibold), never 700 — bold-on-dark blooms for astigmatic readers. Tabular figures enabled globally for counters/minutes/percentages.

Family: **platform sans + platform mono** (SF on iOS, unset `fontFamily`). Bundling Inter/JetBrains Mono is an *optional, beyond-spec* choice — the spec names size/leading/measure, never a family (critique C6).

**Chrome scale → M3 `TextTheme`** (only the roles Onyx uses; height snapped to the 4pt grid).

| M3 role | Size | Weight | Height | L-spacing | Onyx usage |
|---|---|---|---|---|---|
| `displaySmall` | 32 | 600 | 1.25 | -0.5 | completion-ring center %, big readiness number |
| `headlineSmall` | 24 | 600 | 1.33 | -0.25 | sheet titles, hub heading |
| `titleLarge` | 20 | 600 | 1.40 | 0 | AppBar title, goal name |
| `titleMedium` | 16 | 600 | 1.50 | 0.1 | lane row name, group headers |
| `titleSmall` | 14 | 600 | 1.43 | 0.1 | flow-row name, "WHEN TO USE" labels |
| `bodyLarge` | 16 | 400 | 1.50 | 0.15 | default body, sheet copy |
| `bodyMedium` | 14 | 400 | 1.43 | 0.2 | secondary text, subtitles, `~N min left` |
| `bodySmall` | 12 | 400 | 1.33 | 0.3 | timestamps, "not enough data yet", legend |
| `labelLarge` | 14 | 600 | 1.43 | 0.1 | button labels |
| `labelMedium` | 12 | 600 | 1.33 | 0.5 | chips, badge text, KPI caption |
| `labelSmall` | 11 | 600 | 1.45 | 0.5 | state-dot caption, tiny metadata |

**Reading scale → 2 roles on `OnyxTokens`** (kept out of `TextTheme` so nobody reaches for `bodyLarge` inside a study passage). Everything else a passage needs maps to chrome roles (`bodyMedium`/`bodySmall`) or `readBody.copyWith(fontFamily: mono)`.

| Token | Size | Weight | Height | Used for |
|---|---|---|---|---|
| `readTerm` | 22 | 600 | 1.30 | card term / prompt (the "front") |
| `readBody` | 16 | 400 | 1.50 | reveal body, definition, markdown paragraph, code (`.copyWith(mono)`) |

**Text scaling (a11y, non-negotiable).** Respect `MediaQuery.textScalerOf`. **Do not cap chrome scaling** — a hard clamp truncates critical nav and fails WCAG 1.4.4 (critique F11). Instead, lane/flow rows **reflow to two lines** at large scale. Study passages are never clamped.

### 2.3 Spacing — 8pt grid, 4pt half-step

Seven steps ([designsystems.com](https://www.designsystems.com/space-grids-and-layouts/) — odd bases cause "blurry split pixels"). Names are value-agnostic (`space1..space7`), one scheme app-wide (critique C2).

| Token | px | Primary use |
|---|---|---|
| `space1` | 4 | icon↔label gap, chip inner |
| `space2` | 8 | between related lines, badge padding, row gap |
| `space3` | 12 | compact card inset, between chips |
| `space4` | 16 | **default gutter**, card inset, sheet body inset |
| `space5` | 24 | between sections/groups, above CTAs |
| `space6` | 32 | sheet top padding, hero breathing |
| `space7` | 48 | empty-state vertical, above-the-fold separation |

### 2.4 Radius — 3 semantic steps + full

Semantic names, one scheme (critique C3). Calm = soft, consistent rounding.

| Token | px | Applied to |
|---|---|---|
| `radiusChip` | 8 | chips, badges, pills, inline code bg |
| `radiusCard` | 12 | cards (lane/flow/tile), buttons, inputs, callouts, code block |
| `radiusSheet` | 20 | sheet top corners, dialogs, `_TargetCard`, hero containers |
| `radiusFull` | 999 | completion-ring track, status pills, dots, avatars |

### 2.5 Elevation — tonal tiers, near-zero shadow

Depth = **lighter surface**, not shadow ([M3 elevation](https://m3.material.io/styles/elevation/applying-elevation); shadows are near-invisible on dark). `surfaceTint: transparent` kills M3's automatic hue-wash on elevated components; the surface-container ladder carries depth deliberately.

| Tier | Role | Used for | Shadow |
|---|---|---|---|
| 0 · base | `surface` `#121417` | scaffold, session bg | none |
| 1 · card | `surfaceContainerLow` `#1C1F25` | lane/flow rows, tiles, callouts, **code block** | none |
| 2 · raised | `surfaceContainerHigh` `#292E36` | `_TargetCard`, selected/active card, ring track | none |
| 3 · sheet | `surfaceContainerHighest` `#323841` | modal sheets, dialogs | faint top hairline |
| nav | `surfaceContainer` `#22262D` | bottom nav, scrolled AppBar | none |

> **Critique fix (F7/F8).** The code block is **recessed, not raised** — it renders on tier-1 `surfaceContainerLow`, *not* the app's lightest surface. This restores elevation logic and (see §5) lifts every code-token's contrast above AA. No `BoxShadow` extension: the one sheet that floats over the scrim uses a faint **light top-edge hairline** (`onSurface @ 0.06`), because a pure-black shadow on a near-black bg is invisible. No `OnyxElevation` extension (one constant does not need a whole `ThemeExtension` — critique D2).

### 2.6 Motion — quiet, few

Calm register = short + one standard easing, nothing springy ([72technologies](https://www.72technologies.com/blog/motion-ratios-ui-feel-cheap)). Values align with M3/DTCG and existing repo literals (critique C5). **One curve** (critique D3): M3 standard already decelerates on enter, so a separate `decelerate` curve isn't earned.

| Token | Value | Used for |
|---|---|---|
| `motionFast` | 150 ms | micro-feedback: press tint, chip toggle, tooltip |
| `motionBase` | 200 ms | **default**: reveal push-down, expand/collapse, switcher, autoscroll, bar-fill |
| `motionSlow` | 300 ms | full-surface: page transition, sheet enter, scroll-to-group |
| `easeStandard` | `Cubic(0.2, 0, 0, 1)` | everything |

> **No `deliberate` (450 ms), no `emphasized` curve** (critique A3/D3). A slow-on-purpose ring settle "so progress reads as earned" is reward choreography — exactly what constraint 4 forbids. The completion ring settles at `motionBase`/`easeStandard` or snaps. No animation is longer than an ordinary state change.

### 2.6.1 `progressPolicy` — the one rule for "work is happening"

**Never a spinning `CircularProgressIndicator`, anywhere** — a looping ring violates the §8 "no auto-playing/looping animation, the ring only ever *fills*, never spins" rule and the §4.9 "no spinner-on-empty" rule. Progress is shown by *kind of work*:

- **Bounded / determinate work** (a session's cards, a known-length import, promotion stack) → a determinate `LinearProgressIndicator` (the `SessionScaffold` bar: `primary` on `surfaceContainerHigh`, height 4). It shows real fractional progress, never an indefinite sweep.
- **Indeterminate work** (network, sync reconcile, **AI streaming** — e.g. `chat_view.dart`'s `_Thinking`) → a **static status line** (`glyph + text` + `Semantics(liveRegion: true)`, e.g. `◆ Thinking…` / `◆ Syncing…`) **or** a `SkeletonBlock` (§4.9) for content-shaped placeholders. No spinner: the honest signal is a labelled, screen-reader-announced status, not a rotating ring.
- **Reduce-Motion.** Both collapse gracefully: the `LinearProgressIndicator` still steps determinate frames (no marquee sweep), the status line is already static, and any `SkeletonBlock` shimmer freezes to a flat fill under `MediaQuery.disableAnimations` (per §8).

> **Migration.** `CircularProgressIndicator` is a banned literal like a raw hex/radius. Add it to the §7 migration greps: `grep -rn 'CircularProgressIndicator' lib/`.

---

## 3. Theming — mapping to M3

### 3.1 `ColorScheme` (dark)

Seed for the long tail of roles, `.copyWith` for the ~15 we control. Neutral surfaces (no violet tint), single accent, `secondaryContainer` kept as a **faint violet-tinted tonal** so tonal buttons stay a visible affordance (≥3:1 vs card — critique B4; fully neutralizing `secondary` flattened them).

```dart
ColorScheme onyxDarkScheme() {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF6B46C1), brightness: Brightness.dark);
  return base.copyWith(
    primary: const Color(0xFFC9B8F2), onPrimary: const Color(0xFF231737),
    primaryContainer: const Color(0xFF5B4A8C), onPrimaryContainer: const Color(0xFFE4DAFB),
    secondary: const Color(0xFFAEB4BD), onSecondary: const Color(0xFF121417),
    secondaryContainer: const Color(0xFF322C46),        // faint violet tonal (affordance ≥3:1)
    onSecondaryContainer: const Color(0xFFE4DAFB),
    surface: const Color(0xFF121417), onSurface: const Color(0xFFE7E9EC),
    onSurfaceVariant: const Color(0xFFAEB4BD),
    surfaceContainerLowest: const Color(0xFF171A1F),
    surfaceContainerLow: const Color(0xFF1C1F25),
    surfaceContainer: const Color(0xFF22262D),
    surfaceContainerHigh: const Color(0xFF292E36),
    surfaceContainerHighest: const Color(0xFF323841),
    surfaceDim: const Color(0xFF0E1013), surfaceBright: const Color(0xFF323841),
    outline: const Color(0xFF565D68), outlineVariant: const Color(0xFF3C424C),
    error: const Color(0xFFF0757C), onError: const Color(0xFF3A0E12),
    errorContainer: const Color(0xFF5C2126), onErrorContainer: const Color(0xFFFAD6D8),
    surfaceTint: Colors.transparent, scrim: const Color(0xFF000000),
    inverseSurface: const Color(0xFFE7E9EC), onInverseSurface: const Color(0xFF171A1F),
  );
}
```

### 3.2 Two `ThemeExtension`s

Consolidated to **two** classes (critique C1/F9): `OnyxColors` (semantic colors outside `ColorScheme`) + `OnyxTokens` (spacing, radius, opacity, motion, the 2 reading text styles). Parts that proposed 4–5 extensions are treated as value tables, not competing class sets.

```dart
@immutable
class OnyxColors extends ThemeExtension<OnyxColors> {
  final Color good, warn, bad, info, muted;
  const OnyxColors({required this.good, required this.warn, required this.bad,
    required this.info, required this.muted});
  static const dark = OnyxColors(
    good: Color(0xFF4CC38A), warn: Color(0xFFE3B341), bad: Color(0xFFF0757C),
    info: Color(0xFF5AA7E6), muted: Color(0xFF8A9099));
  Color grade(int r) => switch (r) { 1 => bad, 2 => warn, 3 => good, 4 => info, _ => muted };
  // copyWith + lerp (Color.lerp per field) — implement fully; lerp keeps future accent tweaks smooth.
}

@immutable
class OnyxTokens extends ThemeExtension<OnyxTokens> {
  final double space1, space2, space3, space4, space5, space6, space7;
  final double radiusChip, radiusCard, radiusSheet, radiusFull;
  final double emphasisHigh, emphasisMed, emphasisLow;   // 0.87 / 0.60 / 0.38 (decoration-only)
  final double fill, hairline;                            // 0.16 / 0.40 (status tint pair)
  final Duration motionFast, motionBase, motionSlow;
  final Curve easeStandard;
  final TextStyle readTerm, readBody;
  static const standard = OnyxTokens(
    space1: 4, space2: 8, space3: 12, space4: 16, space5: 24, space6: 32, space7: 48,
    radiusChip: 8, radiusCard: 12, radiusSheet: 20, radiusFull: 999,
    emphasisHigh: 0.87, emphasisMed: 0.60, emphasisLow: 0.38, fill: 0.16, hairline: 0.40,
    motionFast: Duration(milliseconds: 150), motionBase: Duration(milliseconds: 200),
    motionSlow: Duration(milliseconds: 300), easeStandard: Cubic(0.2, 0, 0, 1),
    readTerm: TextStyle(fontSize: 22, height: 1.30, fontWeight: FontWeight.w600),
    readBody: TextStyle(fontSize: 16, height: 1.50, fontWeight: FontWeight.w400));
  // convenience getters: EdgeInsets get insetCard => EdgeInsets.all(space4);
  //                      BorderRadius get brCard => BorderRadius.circular(radiusCard);
  // copyWith + lerp (lerpDouble / TextStyle.lerp / lerpDuration; curve snaps at t<0.5).
}
```

> **One value set per family** (critique C4/C5): fill/hairline = **0.16/0.40** (WCAG-verified, two of three parts agreed); emphasis triad defined **once**; motion **150/200/300**. No `state.hover/focus/press` alpha tokens — M3's built-in state layer handles interaction (and PART 3's own rule says "do not add custom press feedback").

### 3.3 `theme.dart` — component themes + text theme

```dart
static ThemeData dark() {
  final scheme = onyxDarkScheme();
  const t = OnyxTokens.standard;
  return ThemeData(
    colorScheme: scheme, useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    textTheme: onyxTextTheme,                       // §2.2 chrome scale
    extensions: const [OnyxColors.dark, OnyxTokens.standard],
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      minimumSize: const Size(64, 48),             // 48dp touch target
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusCard)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      minimumSize: const Size(64, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusCard)))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
    cardTheme: CardThemeData(elevation: 0, color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusCard)), margin: EdgeInsets.zero),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusChip))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: scheme.surfaceContainerHighest,
      elevation: 0, showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(t.radiusSheet)))),
    dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusSheet))),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: scheme.surfaceContainer, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusCard)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder()}),
  );
}
```

App stays pinned `themeMode: ThemeMode.dark`. A `light()` factory may remain a stub but ships no tuned light values (dead code). `lerp` is still implemented for smooth future accent tweaks.

### 3.4 Consumption sugar

```dart
extension OnyxContext on BuildContext {
  OnyxColors get onyx   => Theme.of(this).extension<OnyxColors>()!;
  OnyxTokens get tokens => Theme.of(this).extension<OnyxTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme  get text    => Theme.of(this).textTheme;
}
// usage: padding: context.tokens.insetCard, color: context.onyx.bad, style: context.text.labelMedium
```

---

## 4. Widget catalog

Dependency order for building: **`StatusPill` → data-viz primitives → composites → cross-cutting states**. Widgets read `Theme.of(context)` only; no hex/radius/gap literals. `AppButton` is **not** built (critique D4) — a wrapper that renames M3 buttons but admittedly "can't enforce cardinality" is pure indirection. Use M3 `FilledButton`/`FilledButton.tonal`/`OutlinedButton`/`TextButton` directly (styled centrally in §3.3); keep "exactly one Filled per surface" as a **review rule**.

### 4.1 `StatusPill` — the base status primitive
**Purpose.** The one true way to render any status — guarantees color + shape + number + Semantics are always together (constraint 4). `ConfidenceBadge`, `ReadinessChip`, paused-row, grade tags all compose it.
**Variants.** `tone`: `filled` (confidence, grade tag) · `outlineOnly` (AppBar readiness chip) · `text` (inline "paused"). Color variant: `good/warn/bad/info/muted`. Real configurations in use: **4** (filled-status, outlineOnly-chip, text-dimmed, dense) — document these, don't build the full matrix (critique D5).
**States.** default · dimmed (uses `_ink55`, not `0.38` — F2) · dense (11px).
**Tokens.** fill `color@fill(0.16)`, border `color@hairline(0.40)`, radius `radiusChip`, pad `space2`/`space1`, `labelMedium`.
```
┌───────────────────┐   ┌───────────────────────┐
│ ✓  High · 0.82    │   │ ○  Not scheduled today│  ← dimmed = _ink55 + glyph
└───────────────────┘   └───────────────────────┘
 filled, onyx.good        text, no fill
```
Semantics required and never null: `"Confidence high, 0.82. Tap for why."` `ConfidenceBadge` becomes a thin wrapper (dropping its inline `TextStyle`/`alpha 0.15,0.5`/`radius 6`) and **must pass the numeric confidence score into `value`** (critique E3; confidence-display memory) — icon+label+**number**, not just a hue+word.

> **The cloud-layer statuses route through here too (never color-only).** Every new status the Stage-2 cloud layer introduces renders as a `StatusPill`, so color+shape+label+Semantics travel together by construction: **sync** (`Off` / `On · last synced {t}` / `Sync error`; **"Offline" and "conflict merged" are `muted`, never `bad`** — they are not failures in a local-first app), **AI-tier** (`byoKey` / managed `"coming soon"` disabled row / `off`), **deck-access** (`local` / `restricted` / class-code-bound), **import** (a pulled/updated-upstream marker), and the **draft "not counted"** marker — `StatusPill(muted, "Draft · not counted")`, a normal honest state, never a red "error" tone (`content-creation §3.3`; `registry-and-sync §1.1/§2.2/§5.1`). AI **usage/quota** is the one metering surface and it is a **`CoverageBar` (§4.3/§5), never a ring or a countdown** — a depleting quota must never become a loss-aversion timer (`product-direction §6`; `registry-and-sync §5.2`). The deck **registry carries NO engagement/vanity metrics** — no download counts, ratings, "trending," or "N studying"; card-count is a permitted size fact (`product-direction §8`; `registry-and-sync §4.6`).

### 4.2 Home altitude 0 — `GoalLaneRow`
Trimmed critical-few row (tap = primary act, so a row not a button). `name · status-verb · deadline-or-none · minutes · ›`. **No due-count token, no per-lane pause chrome.** Verb variants: `ready 78%` (dated-target/milestone) / `62% covered` (open-ended) / `can't judge yet` (thin evidence, `muted` italic) — weight-only, no hue. Paused: whole row `_ink55` + `⏸ … · paused`. Deadline uses `warn` only inside ~3d. Semantics folds the whole row into one node.

### 4.3 `SharedBudgetBar` (single implementation, hub-only)
ONE stacked horizontal bar, single accent hue at **graded opacity** (never a rainbow — constraint 2). Segments = `primary` at stepped opacity by legend order; per-goal legend row is the real key. Height 10, `radiusChip`, 1px `surface` gaps.
```
▐███████▏█████▏███▏          one hue, stepped opacity
■ Algorithms 22m   ■ System design 14m   ■ Review 9m
```
> **Critique fix (F4).** Opacity floor is **0.55**, not 0.28 (`primary @0.32` over the track measured **2.13:1 — fails** non-text 3:1). Fewer distinguishable opacity steps is fine because **identity is carried by the legend + per-segment Semantics + the 1px gap**, not by segment contrast. The false "≥3:1 at 0.28" claim is retired. Semantics per segment: `"Algorithms, 22 minutes, 45 percent of today."`

### 4.4 Home altitude 1
- **`ReadinessChip`** (AppBar trailing): `StatusPill(outlineOnly)`, `"Ready 78%"`, tappable → Insights. Demoted on purpose (small-area motivation — constraint 8/9); never a hero number, never green-for-high.
- **`_TargetCard`**: `⚑ Your target · Senior·BigTech · 12d ›`, template-labeled, `radiusSheet`, tier-2. Interview chrome hidden unless template declares it.
- **`CompletionRing`** — the ONE legitimate radial. Center %/`✓`/`—`, sub `~N min left`/`Done for today`/`All caught up`. Arc `primary` on `surfaceContainerHigh` track, stroke 10. **No reward animation** — settles at `motionBase` or snaps; "done" is the absence of the Filled button, not a pop (constraints 4/6). One soft `HapticFeedback.lightImpact()` on reaching 100%, once — categorically not a success buzz.
- **The single Filled** `Continue/Start` — label a pure function of `dailyPlan`, **absent when caught-up.**
- **`TodayFlowRow`** — `● active / ○ dimmed`, name · count · minutes · ›. Non-declared tracks render **dimmed (`_ink55`) "not scheduled today," never hidden** (segment-always honesty, constraint 13; F2 keeps it legible). Semantics speaks the honest state.
- **`CoachBadge`** — ≤1/day nudge: goal + signal + one action (`Apply`/`Not now`/`Undo`). **Silent when on-track** (`SizedBox.shrink`). Nothing mutates silently. `primary` 2px left accent, tier-1, `radiusCard`.
- **`Nof7Indicator`** — the **positive replacement for the deleted `_StreakChip`** (§4.10), the no-loss consistency cue product-direction §9 promises. **7 discrete day-cells, NOT a ring** (the one ring in the app is `CompletionRing`'s completion % — constraint 6): a `Row` of 7 small `radiusChip` cells, oldest→today, each filled `good` if that day was studied else `muted` (unstudied is a calm absence, never `bad`). Caption `"N of last 7 days"` (`labelSmall`). **NO loss-state, NO streak-freeze, NO at-risk/amber, no "keep your streak" copy, no count-up-only number that can only rise** — non-consecutive by construction, so a missed day never destroys anything (this is the whole point of replacing the streak — constraint 4; motivation stance). Color **plus** the discrete count **plus** cell shape carry the reading (never color-only — constraint 7). Renders on **Home, secondary to readiness** (small-area motivation, never a hero — constraints 8/9); absent (not `bad`) before 7 days of history exist. `MergeSemantics` → one node: `"Studied 4 of the last 7 days."`

### 4.5 Study / session
- **`SessionScaffold`** — `✕` · `[🎤][Coach]` · **linear bounded progress bar** (never a ring), counter `4/18`, domain label. Bar `primary` on `surfaceContainerHigh`, height 4, **capped by ramp/taper budget** — a backlog never renders as an avalanche (constraint 14).
- **`CueSection`** ("WHEN TO USE / RECOGNITION") — accented + **expanded by default** (`FlowSpec.cuePolicy`). `primary` left accent bar, header `titleSmall` `primary`, body `readBody`.
- **`RevealBody`** — principle/"why" first (dominant), then instance. Wrapped in `ReadingMeasure` (max ~600px ≈ 66ch at 16px; derive from body size, not a pasted magic constant — critique B2). **No inline wikilinks** — link-free study passages (constraint 15).
- **`VsSiblingRow`** — `[vs. sibling X]` interference-contrast, only on confusable near-adjacent siblings; small tonal button, else absent.
- **Per-state action bars** — before-reveal: one Filled `[Reveal]` (+ tonal `[Answer the coach]`). After-reveal: `GradeButtons` (`Again/Hard/Good/Easy`, colors via `OnyxColors.grade`). **Grade bar cross-fades in place, never slides** (thumb already descending must not mis-hit). Mic stays **out** of the grade bar. `HapticFeedback.selectionClick()` on grade tap — a tick, not the timer's `heavyImpact`. No differential animation by outcome (`Easy` == `Again`).
- **`MockGradeSummary`** — rubric as **bars** (`CoverageBar` per dimension, identical scale), never a radar. `isKickoff` flag replaces the string-prefix hack in `SdMockScreen`.
- **Shared `chat_view.dart` composer** — promoted mic, shared by coach + mocks (one STT composer app-wide).

### 4.6 Goal management (all SheetHeader-topped)
- **`GoalEditorSheet`** field kit: Name (`TextField`) · Which cards (`SegmentedButton` Whole vault/Tag/Folder) · Aiming-at target chips (`FilterChip`) · Deadline row (null default) · **▸ Milestones** `CollapsibleSection` shown **only if template declares a dated-target context** (constraint 6) with dated sub-targets + `[+ Plan]` · Share-of-time `MixSlider` · **one** Filled `[Create goal]` (edit: `✓ Graduate` + `🗑 Delete` `DestructiveRow`). (User-facing "milestone / dated target," never "interview"; the code entity stays `Interview` — `ux-vision §3.4/§5`.)
- **`AdjustMixSheet`** — the SOLE budget editor. `MixSlider`s, **persist on drag-end, no Save button** ("a dial, not a form").
- **`MixSlider`** — `■ label` · M3 `Slider` · live minutes `22m`. Never a text input. Semantics: `"22 minutes, 30 percent of daily time."`

### 4.7 Browse / second-brain
- **`GoalLensSegment`** — `SegmentedButton [This goal · All cards]`, **hidden when `activeGoalCount ≤ 1`**, reads `focusedGoalProvider`.
- **`CardDetailScreen`** — meta row (`ConfidenceBadge` with score) + **"Referenced by" backlinks**, rendered **only when non-empty**. Backlinks tappable *here*, never inside study passages (constraint 15).

### 4.8 Insights
- **`InsightTile`** (small-multiples) — one per goal, identical scale, "needs attention" first: name · readiness % · `Sparkline` · weakest domain + %. Thin-evidence → "not enough data yet," no sparkline. **No cross-goal aggregate** (constraint 3).
- **`OneActionLine`** — single `⚠ focus Caching` under the grid → practice for that domain.
- **`KpiTile` strip** — `[41%][62%][55][4/7]`, each shown **only with data**, tappable → expand its `_Group`. No lifetime totals / vanity metrics.
- **`_Group`** (progressive disclosure) — Readiness **expanded by default**; Memory & recall / Applied / Habits collapsed.
- Group contents (bars/sparklines only): `ReadinessPanel` · retention-by-domain bars · due-forecast histogram · struggling-cards list · applied-perf bars · consistency time-series (**bars/line, no ring, no streak**) · `ForecastBand` (pace, `/insights?focus=pace`).

### 4.9 Cross-cutting states
> **Chrome/state widgets are theme-agnostic; dataviz widgets are token-bound (decided 2026-09-17).** `LoadingView` and `EmptyState` take color from the `ColorScheme` + `TextTheme` only — *never* the Onyx `ThemeExtension`s — because loading/empty/error frames render before, around, and inside every screen (and its widget tests), so they must not require the full app theme in scope. Color still flows from `onyxDarkScheme`, so a restyle carries through; only their micro-spacing is a raw value (not a restyle surface). The bespoke **dataviz** widgets (rings/bars/bands — the actual visual identity) *do* bind `context.tokens`, and their goldens pump `OnyxTheme.dark()`. Clean line: state = theme-agnostic, identity = tokenized.
- **`EmptyState` ✅ (built)** — outlined icon (accent) · scannable title · quiet message · optional action, ~360dp measure. Never a scold. Replaced the ad-hoc `Center>Column` blocks in browse/insights/learn/behavioral/system-design. Golden + structural test.
- **`LoadingView` ✅ (built)** — the calm indeterminate line (§2.6.1): `hourglass` glyph + label + `Semantics(liveRegion)`, `compact` for inline. The spinner ban's replacement.
- **`SkeletonBlock` / `SkeletonLaneRow`** *(not built — build with the Home/Analytics redo)* — shimmer `surfaceContainerHigh → Highest` over `motionSlow`, `radiusChip`. ×2 skeleton lanes on hub. No spinner-on-empty.
- **`ThinEvidence`** — the honest-null helper: `"can't judge yet"` (lanes/readiness), `"not enough data yet"` (tiles/bars). Never a fabricated 0% or a number that can't fall (constraint 3). `muted`, italic.
- **`DestructiveRow`** — `error` color + **outlined shape** + **text** ("Restore"/"Delete") + **confirm dialog**. Never color-only (constraint 7). Distinct shape from neutral buttons around it.
- **`showApiKeySheet` / `showOnyxSheet<T>`** — one wrapper over `showModalBottomSheet` (drag handle, `radiusSheet`, safe area, `barrierColor black@0.45`), SheetHeader-topped, `"Not now"`-able, Keychain-backed. Kills ~15 copy-pasted call sites. Nested detail = in-place `AnimatedSize` sub-section, never a sheet-in-a-sheet.
- **`Toast`** (transient confirm) — a **rare, under-notify** M3 `SnackBar` for the momentary "it happened" of a background action (deck imported / published / sync resolved), where a sheet would over-interrupt. **Text-first, single line, no action-farming, no color-only status** (a status glyph if any); auto-dismisses at `motionSlow`, honors Reduce-Motion (no slide, fades/appears). **Not** for errors (those are honest states — `AiUnavailableState`, `StatusPill(bad)`), **not** for anything the honest states already speak. When in doubt, do **not** toast — under-notify (constraint 8/9).

### 4.10 The streak chip is DELETED, not recolored (constraint 4)
`lib/features/home/readiness_panel.dart:328-357` `_StreakChip` renders `Icons.local_fire_department` + a day count + a loss-aversion tooltip ("Study today to keep your N-day streak") — a textbook streak-with-loss-aversion, a live violation of ux-vision L16/L31/L217 and the gamification-stance. **Delete the `_StreakChip` widget, its `StreakInfo` plumbing, and the `flame #F2792B` color entirely.** Recoloring the flame `good`/green would keep a green flame counting consecutive days — still gamified. A color spec cannot launder a gamification violation by swapping its hue. (This corrects PART 1, which wanted to recolor, and PART 5, which re-added `flame` as a primitive.)

### 4.11 Tablet / large-screen rule (minimal)
Wide screens actively **break the locked ~66ch reading measure** (a teacher's primary device is often a tablet), so this system covers them with **two rules only** — no separate tablet layout, no new tokens:
- **Cap the reading column at ~66ch.** On any width past the measure, `ReadingMeasure` (§4.5, ~600px derived from body size — *not* a new magic constant) stays centered with **inert margins**; text never runs edge-to-edge. This is the interim guard and applies even where two-pane is not built.
- **Optional list+detail two-pane on expanded width.** At the M3 **expanded** breakpoint, Browse / registry / the draft-review list *may* render list+detail side by side; below it, they stay single-column push-navigation. This is additive and optional — the ~66ch cap is the non-negotiable part.

---

## 5. Data-viz styling rules

Bars for comparison, sparklines for trends, a graded band + verbal qualifier for forecasts. Muted foreground; saturation reserved for meaning ([CleanChart](https://www.cleanchart.app/blog/dark-mode-charts); [Wilke Ch.16](https://clauswilke.com/dataviz/visualizing-uncertainty.html)).

- **`Sparkline`** — trends only. Single desaturated line (`onSurfaceVariant`), **no axis, no gridlines**, height 24, stroke 1.5. Optional trailing delta arrow (`good`/`bad` — the only hue). Semantics: `"trend, up, last 7 sessions."`
- **`CoverageBar`** (the workhorse — coverage, retention, applied-perf, rubric, ladder) — label · track (`surfaceContainerHigh`) · fill `primary @ 0.85` (calm/layered) · trailing %. Height 8, `radiusChip`. Grouped variant sorts worst-first, identical scale. **Thin-evidence → track only + "not enough data yet."**
  - **Critique fix (F5).** When a bar is *tinted to mean status* (retention below target → `warn`), color is not the only channel: add a `▲ below target` micro-label or a target-line marker so the good/bad judgment survives color-blindness (constraint 7).
- **`ForecastBand`** — central line `primary` + **graded** ribbon (`primary` fading `.28→.06` outward — darkest = central estimate, avoids deterministic-construal error) + label `"~ Oct 3 · 80% interval"` + verbal qualifier. **Widens with thin evidence** → full-width wash + "can't forecast yet." Home never shows it (pace lives in Insights only). No single `forecastBand` color token — the gradient is computed in the widget from `primary` + the opacity ladder (a one-value token can't express a graded fill — critique E1).
- **`ReadinessBand`** — widens with thin evidence, weakest-link caps it, you-vs-goal ladder (stacked `CoverageBar`s), plus coverage bar. Honest-null: `"can't judge yet."`
- **Grade colors** never appear as a bare dot: always with the label or an ordinal glyph (red/green pair is otherwise color-only — critique F6).

---

## 6. Flutter architecture

Keep the existing flat `widgets/` folder; add a small `design/` sibling. **No** atoms/molecules/organisms taxonomy (over-engineered for ~12 widgets).

```
lib/shared/
  design/
    onyx_design.dart      # barrel export
    _palette.dart         # PRIMITIVES — private raw hex, imported only by the two extensions + theme
    onyx_colors.dart      # ThemeExtension<OnyxColors>
    onyx_tokens.dart      # ThemeExtension<OnyxTokens> (spacing/radius/opacity/motion/2 reading styles)
    onyx_text_theme.dart  # chrome TextTheme
    onyx_code_theme.dart  # syntax highlight map (recessed panel, single-accent keywords)
    context_x.dart        # BuildContext.onyx / .tokens / .colors / .text
  widgets/                # unchanged location; StatusPill added, others migrated in place
    status_pill.dart  sheet_header.dart  confidence_badge.dart  grade_buttons.dart  ...
  status_colors.dart      # @Deprecated shim during migration; deleted at the end
  study_grades.dart       # gradeColor → OnyxColors.grade; label logic stays
lib/app/theme.dart        # assembles scheme + textTheme + component themes + registers extensions
```

**Syntax-highlighting palette** (`onyx_code_theme.dart`): panel = tier-1 `surfaceContainerLow #1C1F25` (**recessed**, F7), plain fg `_ink90`, one violet keyword (echoes the accent), strings/numbers/types from the meaning-palette. **Comment `#9AA1AB` (≈4.7:1 on `#1C1F25`)** — the earlier `#8E959F` on the over-light `#323841` panel measured **3.91:1 and FAILED** the ≥4.5:1 constraint (critique F1); the darker recessed panel + lighter comment both fix it. Recompute deletion/addition on the new panel.

Screens consume via `context.tokens.*` / `context.onyx.*` / `context.colors.*` / `context.text.*` — never `Theme.of(context).extension<...>()!` noise, never a literal.

---

## 7. Incremental adoption roadmap

Each step compiles and ships alone. No big-bang.

- **Step 0 — Scaffold ✅ (done 2026-09-17).** `lib/shared/design/`: `_palette.dart` (flat, alias-free, DTCG-grouped primitives — the door-open seam, §2), `onyx_colors.dart` + `onyx_tokens.dart` (the two extensions, **sourcing every raw value from `_palette`** so numbers live in one place), `context_x.dart` (`context.onyx`/`tokens`/`colors`/`text`), `onyx_design.dart` (barrel; `_palette` deliberately NOT exported). Registered `OnyxColors.dark` + `OnyxTokens.standard` in `theme.dart`; app byte-identical (nothing consumes them yet). Pinned by `test/unit/design_tokens_test.dart` (registration + `grade()` + token values + lerp identity).
- **Step 1 — Color keystone ✅ (done 2026-09-17).** `status_colors.dart` is now a forwarding shim (→ `PaletteColor` static consts, so a restyle still propagates through one place — instance-field access like `OnyxColors.dark.good` isn't const-evaluable, hence the palette forward). `study_grades.gradeColor` → `OnyxColors.grade`. `_StreakChip` + `StreakInfo` + `flame` **deleted** (§4.10). *Deviation:* `callout.dart`'s admonition-only `_violet`/`_cyan` stay local (doc-syntax hues, not status) and its `_info`/`_tip` forward through the shim — reconciling those with `OnyxColors` rides along with the Step-5 migration, not a blocker.
- **Step 2 — `StatusPill` ✅ (done 2026-09-17).** Built; `ConfidenceBadge` delegates (numeric score in `value`). Color+shape+number+Semantics in one place. Golden infra stood up alongside (`test/golden/`, built-in `matchesGoldenFile`, zero-dep — no `alchemist` without internet).
- **Step 3 — Component + text themes ✅ (done 2026-09-17).** `onyxTextTheme` + all component themes + `surfaceTint: transparent` in `theme.dart`. Retroactively fixed radius/padding/targets on stock M3 widgets app-wide. (Custom `pageTransitionsTheme` dropped — the Flutter 3.47 builders needed weren't const/available; M3 defaults stand.)
- **Step 4 — `code_block.dart` surface + palette ⏸ (deferred to the aesthetic pass).** The remaining work is *authoring* an `onyx_code_theme` (a ~15-token syntax map) — that's a human-eye color-judgment task, and `tomorrowNightTheme` already clears WCAG, so it's best done live during the review rather than picked blind.
- **Progress policy — spinner ban ✅ (done 2026-09-17, §2.6.1/§8).** `LoadingView` (calm, theme-agnostic status line) replaced all 16 indeterminate `CircularProgressIndicator`s across 15 screens/widgets; `coach_sheet`/`chat_view` `_Thinking` are static status lines. The one surviving ring (`mock_grade_summary`) is a **determinate** score gauge, not a spinner (its bar-redesign is a Step-6 item).
- **Step 5 — Opportunistic token migration (boy-scout rule, ongoing).** Whenever you touch a widget, swap literals for `context.tokens.*`. Still ~20 files import the `status_colors` shim (Step 7 gate). Migration dashboard = these shrinking greps:
  ```
  grep -rn 'BorderRadius.circular([0-9]' lib/
  grep -rn 'withValues(alpha: 0\.' lib/
  grep -rn 'TextStyle(' lib/shared/widgets/
  grep -rn 'CircularProgressIndicator' lib/   # §2.6.1 — spinner ban DONE; only the determinate mock_grade_summary gauge remains
  ```
- **Step 6 — Catalog, built *when a screen consumes it* (not preemptively).** Partly done: **`EmptyState` ✅** (one scannable state — glyph→title→message→action — replacing the ad-hoc `Center>Column` blocks across browse/insights/learn/behavioral/system-design; golden + structural test) and **`LoadingView` ✅** (see the progress-policy row). The rest — `Sparkline`/`CoverageBar`/`CompletionRing`/`ForecastBand`/`GoalLaneRow`/`SharedBudgetBar`/`TodayFlowRow`/`InsightTile`/`MixSlider`/`ReadinessBand`/`SkeletonBlock`/`ThinEvidence`/`DestructiveRow`/`showOnyxSheet` — have **no consumer yet** (the only bespoke painter today is `today_ring.dart`). Building them now is speculative; instead build each as its owning screen is (re)built — `DestructiveRow` with settings-#67, the dataviz primitives with the Analytics/Home redo, `showOnyxSheet` when a sheet site is next touched — and **add a golden** for each at that point (the real restyle regression net). `[reframed 2026-09-17]`
- **Step 7 — Cleanup (blocked on Step 5).** ~20 files still import `statusGood`/`statusWarn`; when that grep returns only the shim, delete `status_colors.dart`.

**Do NOT:** convert all widgets in one PR · build a Storybook/Widgetbook gallery (worth it at ~40–50 widgets, or once the web app shares components — not ~15) · **stand up a DTCG / Style-Dictionary pipeline *now*** (keep `_palette` DTCG-shaped for a later *mechanical* migration instead — §2) · add a component-token tier · resurrect the light theme · build an `AppButton` wrapper.

---

## 8. Accessibility checklist

- [ ] **Body/status/state text ≥ 4.5:1.** Verified: all primary/secondary/status text on `_n10`; comment `#9AA1AB` on `#1C1F25` (≈4.7). Honest state ("not scheduled," "paused," "No data") uses `_ink55` (5.7:1), never the `0.38` alpha.
- [ ] **Large text + non-text UI ≥ 3:1.** `SharedBudgetBar` segments ≥ 3:1 vs track (opacity floor 0.55, not 0.28); tonal-button fill vs card ≥ 3:1 (faint-violet `secondaryContainer`); focus rings ≥ 3:1.
- [ ] **Never color-only.** Every `StatusPill`/grade/confidence/readiness/tinted-bar pairs color + shape/glyph + number/label + `Semantics`. Grade color never a bare dot. `DestructiveRow` = color + shape + text + confirm.
- [ ] **Confidence shown as a number**, not just a hue+word (`ConfidenceBadge.value` wired to the score — confidence-display memory).
- [ ] **48×48 touch targets** on all buttons/rows/chips (component themes + row hit-area padding).
- [ ] **Text scaling honored, uncapped on chrome.** Lane/flow rows reflow to two lines at large scale; study passages never clamped (no `withClampedTextScaling` — WCAG 1.4.4).
- [ ] **Reduce-Motion honored.** Every custom transition collapses to instant/cross-fade under `MediaQuery.disableAnimations`; verify `showModalBottomSheet` doesn't slide (don't assume a specific visual). No auto-playing/looping animation; the ring only ever *fills*, never spins.
- [ ] **No spinning progress (`progressPolicy`, §2.6.1).** Zero `CircularProgressIndicator` in `lib/`: bounded work → determinate `LinearProgressIndicator`; indeterminate (network/sync/AI-streaming) → a static `glyph+text` `Semantics(liveRegion)` line or a `SkeletonBlock`. Announced to screen readers, never a mute rotating ring.
- [ ] **Semantics grouping.** `MergeSemantics` on composite rows (lane row, budget legend item) so a screen reader hears one coherent node; `ExcludeSemantics` on decorative paint; honest states ("not scheduled") are spoken.
- [ ] **No `#FFF` on `#000`.** Off-white `#E7E9EC` max, base `#121417` min — no halation.

---

### Traceability & corrections folded in
- **Streak deleted, not recolored** (A1/A2) — `flame` and `dataInk` dropped from the palette.
- **Motion cut to `fast/base/slow` + one `easeStandard`** — no `deliberate`/`emphasized` reward-fill (A3/C5/D3).
- **Two extensions** (`OnyxColors` + `OnyxTokens`), one name+value set per token family (C1–C5/D1/D2/F9).
- **Reading body = 16px**, `OnyxType` collapsed to `readTerm`+`readBody`, measure derived not pasted (B1/B2).
- **Code panel recessed to tier-1; comment `#9AA1AB`** — fixes the 3.91:1 AA failure (F1/F7).
- **Dim state text = `_ink55` (5.7:1)**, not `0.38` (F2/F3); **budget-bar floor 0.55**, false 3:1-at-0.28 claim retired (F4).
- **Tinted status bars get shape+label**; grade color never a bare dot (F5/F6).
- **No chrome text-scale cap**; reflow instead (F11). **No `AppButton`** (D4). `secondaryContainer` kept a faint violet tonal so tonal buttons stay visible (B4).
- **Path corrected:** the streak/readiness code is `lib/features/home/readiness_panel.dart`, not `features/insights/` (C7).

Sources: `docs/ux-vision.md` (§2/§3/§7/§8, principles 4–8); [M3 color roles](https://m3.material.io/styles/color/roles) · [elevation](https://m3.material.io/styles/elevation/applying-elevation) · [typography](https://m3.material.io/styles/typography/applying-type); [Flutter ThemeExtension](https://api.flutter.dev/flutter/material/ThemeExtension-class.html) · [Migrate to M3](https://docs.flutter.dev/release/breaking-changes/material-3-migration) · [Accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility); dark-mode & dataviz: [Smashing](https://www.smashingmagazine.com/2025/04/inclusive-dark-mode-designing-accessible-dark-themes/) · [devpalettes](https://devpalettes.com/blog/dark-mode-color-guide/) · [CleanChart](https://www.cleanchart.app/blog/dark-mode-charts) · [Wilke Ch.16](https://clauswilke.com/dataviz/visualizing-uncertainty.html) · [Baymard measure](https://baymard.com/blog/line-length-readability); [8pt grid](https://www.designsystems.com/space-grids-and-layouts/).
