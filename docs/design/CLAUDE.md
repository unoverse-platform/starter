# Unoverse Design — Agent Rulebook

Condensed, non-negotiable rules for building Unoverse components and templates. Full journey: [README](./overview.md), docs 01–09. Deep reference: `docs/unoverse/UNOVERSE_AUTHORING.md`, `UNOVERSE_STATE_MODEL.md` (§5b = the reaction contract), `UNOVERSE_LAYERS.md`, `UNOVERSE_CONFORMANCE.md`.

---

## 1. The architecture in one paragraph

UI is **data**: neutral JSON in `rx/`, rendered natively per platform by a dumb, style-free SDK. Templates are **MCP Apps** (manifest = the envelope; sends = `tools/call`; answers = elicitations; state on the MCP `/stream`). Interaction follows the **reaction contract**: a component writes ONLY its own slice; templates are pure views that react via state selectors; **inline is the universal default**. You author data; you never touch the SDK, transport, or platform code.

## 2. The anatomy (both kinds share the folder grammar)

| | Component | Template |
|---|---|---|
| Contract file | `manifest.json` = render contract (arrival `defaultState`, open name, default `"inline"`) + discovery meta (`title`/`description` ≤120/`whenToUse` utterance-shaped). Presence = discoverable; envelope never duplicates it | `manifest.json` = THE envelope: name/whenToUse/`defaultState`/`inputSchema`/`stateOrder`/`binding{workflow,trigger}`/`layout`/`service?` — no `<name>.json` |
| Envelope | `<name>.json`: name/category/`nodeSize`/`outputs`/`props`/`state`/`stateOrder`/`root` | — |
| Faces/root | `root` = `Switch on defaultState` → `$include layouts/<state>` (**filename = state name**: `layouts/inline`, `layouts/focused`, custom `layouts/product`); `default` case → inline | a SET of `layouts/` — one per component view + the default (`manifest.layout`); the active layout = the layout NAMED after the latest surfaced view (name-sync, derived), else the default |
| Layers | `states/` = private steps (wizard questions) + `stateOrder` names exactly those files | `states/` = LOCAL states only (welcome/conversation/call phases) — available in the layouts that include them; component-driven views are LAYOUTS (rule of thumb: component causes it = layout, template knows it = state) |
| Local partials | `components/` (earned: 2+ states share a shape); cross-component shapes = atoms in `rx/atoms/` (`Ref`; authoring-time only — the server expands before serving) | `components/` (header, composer-bar, turns) |
| Flat form | just `<name>.json` + `root` — one face, no manifest/layouts/states. Structure is EARNED | — |

**Two component tiers:** design system = the installed marketplace package (generic, org-neutral — any org); org = `rx/<project>/components/` (**org-private** — that client's own, discoverable only in their apps). Names UNIQUE across all tiers (lint error on collision); org may reference design-system, design-system NEVER references org (lint). URIs: `unoverse://components/<org>/<name>` (org) · `unoverse://components/<name>` (design system; bare also resolves any unique name).

## 3. Three homes — everything a component shows (slop rule)

1. **Static content** → hardcoded LITERALS in the layout (`value`, literal `items: []` on Each, `src`). Never props, never `state`.
2. **`state` block** → **SCALAR internal view-state only** (`step`, `phase`, `progressPct`) with initial values. An **array/object/URL in `state` is slop** — the linter rejects it.
3. **`props`** → ONLY `input: true` workflow-fed data (a finder's matched `products`), `default` = the preview mock. Usually empty.

Arrival `defaultState` lives in the **manifest**, not the state block.

**Prop names = the data contract.** Source data (content rows, node outputs) seeds component state **as-is, by name — no projection, no mapping**; a bind whose name the source doesn't carry silently renders the preview `default` (tell: title streams, image/tagline stay mock). Content-attached cards MUST use the writer vocabulary: `title` `tagline` `description` `bodyCopy` `introParagraph` `primaryImage` `images` `link` `callToAction` — never invent (`image`/`subtitle`/`category`/`location` are misses). Fix = rename the prop to the source field, never add glue. Guard: `content-card-hydration.test.ts`; law: `UNOVERSE_MCP_TEMPLATE_PROTOCOL.md` §Content-attached cards; walkthrough: docs/design/03 §Prop names.

**Naming = discoverability (docs/design/05 §Naming; canonical: docs/nodes/14):** **Spatial** embeds `title. whenToUse||description [category]` against the USER'S OWN WORDS. title = the thing itself; description = what it IS, ≤120; whenToUse = utterance-shaped, outcome-first, opening words dominate; category = job domain. Disqualify by property, NEVER name a sibling; a fallback surface never enumerates siblings' jobs (generalist trap).

**Briefs (AI-fed components):** a `brief` sits ON the node that renders what it describes — `{ description, maxLength }` next to the bound element, `{ description, minItems, maxItems }` on the Each (JSON Schema's own words — the brief IS the schema fragment), plain-string context on a face/partial root; NEVER in the manifest or a separate file. The platform compiles briefs into the component's **MCP tool schema** (keys pass through verbatim as native JSON Schema; Each template binds→items schema) — the schema IS the instruction channel; grounding (fill only from **Spatial** results, never invent) is injected by the compiler. Closed shape, lint-enforced (docs/design/03).

## 4. The reaction contract — state-selected UI (STATE_MODEL §5b)

- **A component is a `Switch` of views, one active.** State is **local**; the **view** (`defaultState`) is the interface — the only thing a template sees. A component's internal state (`step`, `phase`) is private. A **surface-only component** omits inline/default faces + declares a surfaced arrival (manifest.defaultState = one of its cases): it renders ONLY while surfaced and retires invisibly when the conversation moves on (lint-recognized).
- **Lifetime (OPTIONAL manifest flag)**: `"lifetime": "conversation"` = a durable, conversation-scoped surface (cart / itinerary / composed page) — keyed by the CONVERSATION (re-calls hydrate the SAME slice, merge not re-place) and exempt from the new-turn reset; it stays until replaced, self-closed, or a **template swap (the hard refresh boundary — a new shell retires every surface, durable included)**. Default `"turn"` = the universal reset above. Values closed to `turn | conversation` (lint-checked).
- **A template is in exactly ONE state at a time** — the latest surfaced view (derived, never stored; "" = conversation/welcome base). **Exactly one reaction surface renders**: the active state's. **Layouts sync by NAME**: the active layout = the layout named after that view (a card entering `product` selects the `product` layout); a layout must surface its own view inside (guard). Other states' data persists untouched and re-presents when active again. Surfaces never stack; panel combinations cannot exist. Lint: one surface per view, surfaces claim ONE view by `eq`.
- **A surface's single occupant FILLS the surface** (`limit: 1` → the SDK gives the instance the frame's full height; the face's `height: "full"` resolves against it). NEVER per-face `minHeight: full` hacks to fill a panel; rails (no limit) stay content-sized.
- A view changes two ways, both `setValue` into **its own slice**: arrival (manifest `defaultState`) or user interaction. Close = it sets itself back (`inline`); its expanded face carries its own ✕.
- **One instance → one placeholder.** Every view has a placeholder: the **flow** = `inline`; a **reaction surface** = a named view. While a view matches a surface, the instance **lifts out of the flow into the surface** (the SDK renders it in exactly one place — never both). No `hideBelow`/overlay trick to hide a flow copy. An unmatched view stays in the flow. **Many instances** are fine — the template decides a placeholder's layout (flow list / one focus / rail) via `select`.
- Templates react via `ComponentSlot.select.where: { field: "defaultState", eq: "<name>" }` (+ `limit: 1`, most-recent-wins) — **never `type`-pinned, never by id, never on a component's internal state key** (all lint-flagged). Template-focus is DERIVED (does anything match?), never stored.
- `setTemplateValue` = ONLY the template's own chrome (panels, draft). A component writing template state to open a surface is the deprecated bridge — linted.
- Reserved behaviors: `template` swaps the shell; **inline is the universal default**. State names are otherwise OPEN — keep them consistent per org.

## 5. Non-negotiable style/structure rules

1. **Closed primitive set** — `Box Stack Row Column Each Switch ComponentSlot Timeline · Text Image Button Input Markdown Skeleton Icon · Ref $include`. Conditions: `eq ne in` truthy only. Compose; never invent.
2. **LAW 1: zero raw values** — no `px/rem/em/#hex`; **semantic** token names only; style KEYS are closed (no web-isms); dimension VALUES must be real space-scale steps (`0 1 1.5 2 3 4 5 6 7 8 10 12 16 20 24 28 40 50 75 90 100 120 140 160 180 200`, `full`, `auto`) — an invented step is silently broken CSS.
3. **Derived values in the node/workflow** — no arithmetic in definitions.
4. **A component owns its faces and size; the template owns only the framing.** No component-type rules in templates.
5. **A Switch case never re-guards its own discriminant**; one discriminant per axis, no boolean soup.
6. **Never hand-roll transport** — the SDK's MCP path is the only one.
7. **Locked state is read-only**: conversation/lifecycle (project `isStreaming`/`isEmpty`), voice (`service: "voice"` in the manifest; branch on the projected `callState`), host chrome (host props).
8. **Icon quirk**: literal glyph = `icon: "phone"`; bound = `bind: { name: field }`. An atom's `bind` is field-lookup ONLY — `Ref props` remaps FIELDS, never carries literals. To pass a literal, use **`Ref with`**: `{ "type": "Ref", "ref": "button", "with": { "label": "Learn more", "icon": "arrowRight" }, "action": { … } }` — a bind whose field is a `with` key becomes a hardcoded attribute; a truthy `with` key drops a matching `visibleWhen` guard (unprovided key ⇒ the piece stays hidden); `{{key}}` bindings take the literal.
9. **Sizing in one sentence**: the app = the ACTIVE LAYOUT's total — nothing else, ever (core panel + that layout's surface panel). The core surface (chat column) = a panel that is ALWAYS open (`appWidth`); each state's panel declares its width on its surface; ONE state active ⇒ the width is always one of a small known set, bounded by construction — nothing can combine, overflow, squeeze, or clip. Host animates between known widths; the core never moves. Values = the org's STANDARD SIZES (`styles/semantic/app-sizes.json`: `chat`/`rail`/`panel`, theme-resolved like any token, lint-checked) — raw CSS appWidth is DEAD (lint error). ONE declaration per panel (panel/frame never declares width/flex — lint error); an overlay (`inset: 0`, e.g. focus) declares NOTHING and needs no layout; appWidth NEVER on a layout root, NEVER visibleWhen-guarded (a conditional arrangement is a LAYOUT); manifest `width`/`focusWidth` are DEAD (lint error); never `maxWidth` in the tree to size the app; root gets `overflow: hidden` ([05](./05-templates.md)).

## 6. Workflow checklist

1. Read the matching journey doc ([03](./03-components.md) component / [05](./05-templates.md) template / [06](./06-styles-and-tokens.md) styles); study the exemplars: `productfinder`/`planfinder` (components), `acmechatlayout` (template).
2. Author to the anatomy in §2; put every shown thing in its ONE home (§3).
3. **Publish from Studio — lint 0 errors required**; it enforces §2–§5 with doc-cited messages. Justify any warning.
4. Preview in **Studio** — mock (prop defaults + state picker + Inline/Focused toggle), then live. Debug order: stream log → state inspector → definition. Never edit on a guess.

## 7. Error → fix quick table

| Symptom | Fix |
|---|---|
| Blank image/icon after passing content into an atom | literals don't travel through `Ref props` (fields only) — pass them via `Ref with` (§5.8) |
| Renders a field's NAME as text | bare field ref on an absent field — hardcode the literal, or object-form `visibleWhen` |
| Focus surface won't open | the surface must `select.where` on the state the component actually writes; check the state inspector |
| Focus won't close | the component's ✕ must `setValue { defaultState: "inline" }` on ITS OWN slice |
| Component invisible in a template | unknown state name + no matching surface = inline is where it went — check the flow slot exists |
| Card shows mock image/tagline while title streams | prop name isn't the source's field name (hydration is by-name, no mapping) — rename to the writer vocabulary (§3) |
| Style ignored / element auto-sizes | raw value, unknown style key, or off-scale step — lint tells you which |
| Edit does nothing | node contract changed (props/structure) → re-publish from Studio |
| AI never picks it | manifest `whenToUse` is selector-shaped or missing — write the user's words |

Full table: [09 — Troubleshooting](./09-troubleshooting.md).
