# Unoverse templates — SAB

Template (layout / MCP-App) definitions — neutral primitive trees that read the
**single shared state** (history + components) and arrange it. A template **owns
nothing**: it reads the store and lays out what it finds, so it is swappable
without losing the conversation (`UNOVERSE_SPEC.md` §2e-0).

## Discoverability meta (REQUIRED — templates are essential, like MCPs)

Every template's `manifest.json` carries the same four meta fields nodes have —
they decide whether `findIntent` can ever surface it in spatial discovery:

- **`name`** — human display name ("Bank Transfer").
- **`description`** — what it is (shows in the Content library list).
- **`whenToUse`** — the **selection text**: embedded as
  `` `${title}. ${whenToUse || description} [${category}]` `` and ranked against
  user intent. Write it **outcome-first in the user's vocabulary** ("Transfer or
  send money — …"), never mechanism-first ("Two-column split layout…"). Full
  rules: `docs-starter/nodes/14-node-discoverability.md` — they apply verbatim.
- **`category`** — the domain of the job (Payments, Cards, Assistant, …).

The manifest wins over the template def; the reconcile warns for any enabled
template missing `whenToUse`. Registry meta embeds AS-IS (no LLM rewrite).

## Authored

- **`sabchatlayout/`** (entry `sabchatlayout.json` + `$include` parts) — the
  SAB-branded chat surface, composed entirely in **data**: welcome screen on
  `isEmpty` (logo, starter prompts), bottom-anchored `Timeline` conversation
  (red user bubbles, avatar + `ComponentSlot` assistant turns), thinking dots
  while `streaming` AND `empty`, and a pill composer bound to the shared
  `draft`. Selected via `WORKFLOW_STARTED` `metadata.template`; loaded with
  `resources/read unoverse://templates/SABChatLayout`. Never streamed as a
  component.
- **`sabvoicelayout/`** — the full-duplex voice assistant surface; branches
  call phases on the derived `callState` (idle / active / agentSpeaking /
  userSpeaking). Cards it surfaces open in a side focus panel.
- **`banktransfer/`** — focused money-transfer app (`mode: focus`): source
  account, beneficiary, amount/memo, review, confirm.
- **`findcard/`** — focused credit-card eligibility and best-fit assessment
  (`mode: focus`).

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
