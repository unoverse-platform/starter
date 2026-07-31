# Playbook — Templates (MCP apps)

**Read first:** `docs/design/templates.md` (layouts + manifest-as-envelope) +
`docs/design/state.md` (the reaction contract + name-sync). Deep law:
`UNOVERSE_STATE_MODEL.md` §5b, `UNOVERSE_LAYERS.md`. Everything in the component
playbook (closed vocabulary, tokens, scale steps) applies here too.

## THE model — layouts sync by name

A component is a Switch of **faces**; a template is a set of **layouts** — same
mechanism, two tiers, connected by ONE rule:

> A component enters a view → the template presents the layout of the same name.
> No matching layout → the default layout; the component renders inline.

Derived off the store, never stored, no wiring — the component never knows templates
exist. **Rule of thumb: component causes it = layout; template knows it = state.**

## The anatomy — manifest-only (NO `<name>.json` envelope)

```
apps/unoverse/rx/orgs/<org>/templates/<name>/
  manifest.json    # THE ENVELOPE — the whole app contract (below)
  layouts/         # the ARRANGEMENTS — one per component view + the default
    standard.json  #   the default (manifest.layout): the core alone
    products.json  #   view "products" → core + cards rail
    product.json   #   view "product"  → core + detail panel
  components/      # template-local partials (core, header, composer-bar, turns…)
  states/          # LOCAL states only (welcome, conversation, call phases) —
                   # available in exactly the layouts whose trees include them
```

Each layout = a complete arrangement: `{ "$include": "components/core" }` + that view's
surface. Shared chrome lives ONCE in `components/`; every layout includes it. A layout
named after a view MUST contain a surface selecting that view (guard-enforced) — the
name claims the instance, the surface renders it.

## manifest.json (the app contract)

Required: `name` · `description` (what it IS, ≤120) · `whenToUse` (utterance-shaped — the
USER's words; findIntent ranks on it — the OPENING words carry the ranking; disqualify by
property, never by naming siblings; full contract: docs/design/05 §Naming) ·
`category` · `defaultState` (`"template"` = the full surface) · `inputSchema` ·
`layout` (the DEFAULT layout name) · `stateOrder` (local states + layouts, picker order) ·
`binding` (`workflow` + `trigger` — the app OWNS its workflow; without a real binding it
is not done). Optional: `preview` (the per-LAYOUT mock map for Studio —
`{ "products": ["productcard", "productcard"] }`; repeated name = several instances),
`autoTrigger`, `expose`, `service` (`"voice"` — the channel instantiates the native
service, which projects `callState` into scope).

**The generalist trap:** a home/fallback surface must NOT enumerate its siblings' jobs —
it owns general help and cedes specific jobs by property, naming none.

## Sizing — each layout owns its widths

The app = the ACTIVE layout's total, nothing else ever. Inside a layout: the core panel
is always open (`appWidth` on the core box), the surface panel declares its width on the
ComponentSlot. Lint-enforced:
- `appWidth` = a NAMED size from the org's `styles/semantic/app-sizes.json`
  (`chat` · `chat-slim` · `rail` · `panel`) — raw CSS is an ERROR.
- ONE declaration per panel — the frame never declares width/flex.
- NEVER on a layout root; NEVER `visibleWhen`-guarded (a conditional arrangement is a
  LAYOUT, selected by name).
- An OVERLAY surface (`inset: 0` over the core) declares NO appWidth and needs NO layout
  of its own — reach for a layout when the ARRANGEMENT changes.
- Nothing in the manifest sizes the app (`width`/`focusWidth` dead — lint error).
- Layout root: `overflow: hidden`.

## Surfaces — templates REACT, they never own

One instance → one placeholder: the flow is the placeholder for `inline`; a surface (or
a layout, via its inner surface) is the placeholder for a named view. The SDK keeps a
claimed instance out of the flow — never hide a flow copy yourself.

- **Flow slot**: `{ "type": "ComponentSlot", "select": {} }` — always present.
- **Reaction surface**: select by the VIEW, never by type/id:
  ```jsonc
  { "type": "ComponentSlot", "appWidth": "panel",
    "select": { "from": "all", "where": { "field": "defaultState", "eq": "product" }, "limit": 1 },
    "frame": { /* chrome; an inner bare ComponentSlot marks the placement */ } }
  ```
  ❌ `select: { type: [...] }`, ❌ `where.field` ≠ `defaultState`, ❌ template chrome
  writing a component's slice — all lint-flagged.
- **Template state** (`setTemplateValue`) is ONLY for the template's own chrome (a
  disclosure, the composer `draft`). "Is something focused" is DERIVED — never stored.
- **Chrome reacts via `surfacedView`** (SDK-projected active view name, `""` = all
  inline): `visibleWhen { "field": "surfacedView", "in": ["", "products"] }`.
- **A `limit: 1` surface's occupant FILLS it** automatically — never sprinkle
  `minHeight: full` through faces. Rails (no limit) keep content-sized cards.
- A full layer caps its height and scrolls its BODY only (`flex: 1` + `minHeight: 0` +
  `overflow: auto`; header/footer pinned).

## Voice templates

`"service": "voice"` in the manifest. Call phases (`states/idle…user-speaking`) are
LOCAL states included by the cores; typically a wide core in the default layout and a
slim core (`chat-slim`) in the card layouts. Cards during a call select layouts by name
exactly as in chat. Audio is never wired in a definition.

## New org?

`rx/orgs/<org>/` = `templates/` + optional `components/` (org-private microapps, names
unique across tiers) + a **complete self-contained** `styles/` (copy
`rx/orgs/default/styles` and re-value the base scales). Addresses: apps
`unoverse://apps/<org>/<name>`, org components `unoverse://components/<org>/<name>`,
themes `unoverse://theme/<org>/<theme>`.

## Validate & ship

1. `./unoverse lint` — 0 errors (layout/name-sync rules, widths, reaction rules, tokens).
2. Restart unoverse — the node re-synthesizes.
3. **See it**: Studio — layout pills on top (default first, stateOrder order), local
   states down the left, freely combinable; acting inside the preview transitions like
   the runtime. Then run it live: the bound workflow streams components, and entering a
   view swaps the layout end-to-end.
