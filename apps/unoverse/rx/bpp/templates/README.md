# Unoverse templates — BPP

Template (layout / MCP-App) definitions — neutral primitive trees that read the
**single shared state** (history + components) and arrange it. A template **owns
nothing**: it reads the store and lays out what it finds, so it is swappable
without losing the conversation (`UNOVERSE_SPEC.md` §2e-0).

## Discoverability meta (REQUIRED — templates are essential, like MCPs)

Every template's `manifest.json` carries the same four meta fields nodes have —
they decide whether `findIntent` can ever surface it in spatial discovery:

- **`name`** — human display name ("Find Journey").
- **`description`** — what it is (shows in the Content library list).
- **`whenToUse`** — the **selection text**: embedded as
  `` `${title}. ${whenToUse || description} [${category}]` `` and ranked against
  user intent. Write it **outcome-first in the user's vocabulary** ("Find a
  course, qualification or apprenticeship — …"), never mechanism-first. Full
  rules: `docs-starter/nodes/14-node-discoverability.md` — they apply verbatim.
- **`category`** — the domain of the job (Assistant, Courses, …).

The manifest wins over the template def; the reconcile warns for any enabled
template missing `whenToUse`. Registry meta embeds AS-IS (no LLM rewrite).

## Authored

- **`bppchatlayout/`** — the BPP-branded chat home (`mode: template`): greets
  the learner with AI-guided journey starters and free-form conversation about
  courses, qualifications and apprenticeships. Selected via `WORKFLOW_STARTED`
  `metadata.template`; loaded with `resources/read unoverse://templates/BPPChatLayout`.
- **`findjourney/`** — focused guided learning-journey finder (`mode: focus`):
  six quick questions (career stage, situation, subject, route, study mode,
  time commitment), then a course search returning matched recommendations.

## Primitives & vocab it relies on (all implemented in the web SDK)

- **Structural:** `Box`/`Row`/`Column`, `Each` (map an array), `ComponentSlot` /
  `Timeline` (project the store's timeline; `Timeline` renders per-turn `user` /
  `assistant` sub-trees).
- **Leaves:** `Text`, `Image`, `Button` (label *or* composed children), `Input`
  (local *or* controlled via `bind.value`), `Markdown`, `Skeleton`, `Icon`
  (served glyph — the pack lives on the server, never the SDK).
- **Style vocab:** design tokens + `style.animation` → served `theme.keyframes`;
  served recipes (`theme.prose`, `theme.skeleton`, `theme.icons`). The SDK authors
  **zero** style values (golden-rule enforced).
- **Neutral state the renderer projects into scope** (never UX policy): root
  `isEmpty` / `hasMessages` / `draft`; per-turn `text` / `time` / `streaming` /
  `empty` / `active`. Definitions compose conditions with `visibleWhen`
  (nesting = logical AND).

## How a template renders

`resources/read unoverse://templates/{name}` (MCP — the recipe, served by the
definition server) → the renderer walks the primitive tree → each `ComponentSlot` /
`Timeline` projects the store's timeline (select → filter by `typeOf` → render each
pointer's leaf via `StreamedUnoverseComponent`). Live component data arrives
separately over the channel's data-plane stream into the **same store**. Recipe =
served definition; conversation = the store. The two are joined only by the store.
