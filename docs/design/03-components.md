---
sidebarTitle: "Components"
title: "Components"
---

**A component is a light, self-contained app: its manifest is the contract, its layouts are its faces, and everything it shows has exactly one home.**

---

## 📁 The anatomy

```
rx/components/productfinder/
├── productfinder.json    # envelope: name, nodeSize, outputs, props, state, stateOrder, root
├── manifest.json         # the RENDER CONTRACT + discovery meta (see below)
├── layouts/              # the FACES — one file per master state; filename = state name
│   ├── inline.json       #   the in-conversation card (the universal default)
│   └── focused.json      #   the expanded face (or any custom state: layouts/product.json)
├── states/               # the component's PRIVATE steps (a wizard's questions)
│   ├── goals.json … results.json
└── components/           # component-local shared partials (only when 2+ states share a shape)
```

A **flat component** (a simple card, a chart) is the reduced form: just `<name>.json` with its `root` — one face, no manifest, no `layouts/`, no `states/`. Simplicity is the default; structure is **earned**.

**Components live in TWO tiers** (same anatomy in both):

| Tier | Home | Scope | URI |
|---|---|---|---|
| **Design system** | `rx/components/<name>/` | generic, org-neutral — any org can use it (cards, charts, markdown, media) | `unoverse://components/<name>` |
| **Org** | `rx/<project>/components/<name>/` | **org-private** — that client's own components/microapps, usable and discoverable only inside that org's apps and conversations | `unoverse://components/<org>/<name>` |

Names are **unique across the design system and every org** — a collision is a lint error (no shadowing). Both address forms are first-class — the bare URI is the canonical address for a design-system component, the org URI for an org component; uniqueness means a bare ref also resolves an org component unambiguously. Direction rule: org things may reference design-system things; **design-system things never reference org things** (lint-enforced, including template preview lists).

- File lookup is case-insensitive by filename; `name` is the display/type name.
- **`components/` vs atoms:** a shape shared across *this component's* states → its own `components/` (`$include`). A shape shared across *many components* (a close button, a choice row) → a universal atom in `rx/atoms/` (`Ref`). Used once → inline it. Atoms are **authoring-time only**: the server always expands them before serving (channels only ever receive fully-expanded primitive trees; atoms are never served, never enumerable, and have no **Studio** view). A `Ref`'s `props` remaps *fields*; its `with` passes *literals* into the atom — `{ "type": "Ref", "ref": "button", "with": { "label": "Learn more", "icon": "arrowRight" }, "action": { … } }` hardcodes those attributes, and a truthy `with` key satisfies (drops) a matching `visibleWhen` guard, so unprovided pieces stay hidden.

---

## 📜 The manifest — the render contract

```jsonc
// rx/components/productfinder/manifest.json
{
  "title": "Product Finder",
  "description": "Personalised product recommendations matched to your goals.",   // what it IS, ≤120 chars
  "whenToUse": "Find the right product or qualification for my career goals…",    // the USER's words — findIntent ranks on this
  "category": "Input",
  "version": "1.0.0",
  "defaultState": "focused"    // the ARRIVAL state — an OPEN name; omit for "inline"
}
```

- **`defaultState` = the state the component arrives in.** An open name (`inline`, `focused`, `product`, anything). The server injects it into the component's scope, so it renders that face the moment it streams in. Default: `inline`.
- **`lifetime` (OPTIONAL) = how long the rendered instance survives.** Default `"turn"`: the universal reset — the instance returns to inline / retires on the next user turn ([04 §Two lifetimes](./04-state.md)). `"conversation"`: a **durable, conversation-scoped surface** (a cart, an itinerary, a composed page) — the platform keys the instance by the *conversation* (every re-call hydrates the SAME slice: merge, never re-place) and the new-turn reset skips it; it stays on screen until replaced, self-closed, or a **new template loads** (the template swap is the hard refresh boundary). Closed set `turn | conversation`, lint-checked.
- **Manifest presence = spatially discoverable.** The discovery meta (`title`/`description`/`whenToUse`) lives here and ONLY here — never duplicated in the envelope. A component that's only ever streamed by a workflow, arrives inline, and needs no discovery can skip the manifest entirely.
- `whenToUse` is **utterance-shaped** — the words a user would say ("find the right product for me"), never selector-shaped dev framing ("use this when the user asks…").
- **Naming is discoverability** ([05 §Naming](./05-templates.md) — canonical: `docs/nodes/14-node-discoverability.md`). **Spatial** embeds `` `title. whenToUse||description [category]` `` and ranks it against the user's own words: `title` = the thing itself (no mechanism, no org prefix), `description` = one ≤120-char line of what it IS, `whenToUse`'s **opening words** carry the ranking, `category` = the job's domain. Disqualify by property, never by naming a sibling.

---

## 🏠 Three homes — everything the component shows

| What it is | Where it lives | Example |
|---|---|---|
| **Static content** — copy, titles, option lists, images | **hardcoded literals in the layout** (`value` on Text, `items` on Each, `src` on Image) | a wizard's question text, its hero image |
| **Internal view-state** — the SCALAR keys the component's own actions write | the **`state` block** (initial values) | `step`, `phase`, `progressPct`, `questionLabel` |
| **Workflow-fed data** — what a run streams in | **`props` with `input: true`** (the `default` is the preview mock) | a finder's matched `products`, the user's real accounts |

Anything else is **slop**, and the linter rejects it. The tell: **an array, object, or URL in the `state` block is never view-state** — it's content (→ hardcode) or data (→ `input: true` prop). A contained microapp usually has an *empty or absent* props block.

### 🔑 Prop names are the data contract — use the writer's names, never invent

How workflow data reaches a prop: the source object (a content row, a node's output) is
seeded into the component's state **as-is — by name, no projection, no mapping layer**.
Every `bind` looks its value up BY NAME; a name the source doesn't carry silently renders
the preview `default` instead (the classic tell: title/description stream correctly while
the image and tagline stay stuck on mocks). If a bind misses, **rename the component's
prop to the source's field name — never add mapping glue.**

For **content-attached cards** (a row with `metadata.app` hydrating your card), the field
vocabulary is the content writer's, and it is fixed:

| Prop name | What arrives |
|---|---|
| `title` | the row's title |
| `description` | short summary |
| `tagline` | one-line hook / category line |
| `bodyCopy` | long-form markdown body |
| `introParagraph` | intro paragraph |
| `primaryImage` | hero image URL |
| `images` | image URL array |
| `link` | labelled markdown link to the source page (render with `Markdown`) |
| `callToAction` | CTA label |

❌ `image`, `imageUrl`, `photo`, `subtitle`, `category`, `location` — inventions; the bind
misses and the mock leaks into production. The canonical row shape and the guard live in
`server/src/runtime/content-card-hydration.test.ts` — it walks every layout of every
attachable component and fails the build on a bind the row can't satisfy. Deep law:
`UNOVERSE_MCP_TEMPLATE_PROTOCOL.md` §Content-attached cards.

```jsonc
// productfinder.json (envelope) — the state block is lean scalars only
"state": { "step": "goals", "phase": "about", "progressPct": "16%", "questionLabel": "Question 1 of 6" },
"props": {
  "products": { "type": "array", "input": true, "default": [ /* 3 mock products for preview */ ] }
}
```

---

## 🎭 The faces — root switches on `defaultState`

Every faced component's root is the same three lines: a `Switch` on `defaultState` whose cases `$include` a layout **named after the state**:

```jsonc
"root": {
  "type": "Box",
  "style": { "width": "full", "height": "full", "container": "inline-size" },
  "children": [
    { "type": "Switch", "on": "defaultState",
      "cases": {
        "inline":  { "$include": "layouts/inline" },
        "focused": { "$include": "layouts/focused" },
        "default": { "$include": "layouts/inline" }    // inline is the universal default
      } }
  ]
}
```

- **The layout filename = the state name.** A custom arrival state `product` gets `layouts/product.json` — no special-casing, any open name works.
- **The face is a state decision, never a width decision.** The same `defaultState` write that makes a template's surface react also flips the face. Container queries (`hideBelow`) are for fine adjustments *inside* a face, never for picking one.
- **A `hideBelow` threshold must be reachable by the card itself** — keep it *below* the layout's own `maxWidth`. A threshold at or above it can only be satisfied by the surrounding surface, so the element shows on a wide **Studio** stage and silently vanishes in a chat column (linted).
- The component's own buttons move it: expand = `setValue { defaultState: "focused" }`, its focused face carries its own ✕ that sets it back to `"inline"`. **A component writes only its own slice** — how templates react is [04 — State](./04-state.md).

---

## ✍️ Briefed components — the design briefs the AI

A **brief** is metadata that tells an AI what should fill a bound element. It sits **on the node that renders what it describes** — next to the `bind` it governs, never in a separate file or the manifest:

```jsonc
{ "type": "Text",
  "brief": { "description": "Name the day in the guest's OWN emotional language — never a generic label.",
             "maxLength": 60 },
  "bind": { "value": "headline" }, "style": { … } }

{ "type": "Each",
  "brief": { "description": "Order as the day would be lived. Variety of kind over similarity.",
             "minItems": 3, "maxItems": 5 },
  "bind": { "items": "sections" },
  "template": { "$include": "components/story-section" } }   // its binds define the item shape
```

- **Shape (linted, closed):** a string (just the description) or `{ description, maxLength }` on a bound element, `{ description, minItems, maxItems }` on an `Each` — **JSON Schema's own vocabulary**, because the brief IS the schema fragment it compiles to. A brief on a node with **no** bind (a face or partial root) is *composition context* — rules about the whole, like ordering or refinement behavior.
- **What it becomes — this is MCP-native, no side-channel:** the platform compiles every brief into the component's **MCP tool schema** (each key passes through verbatim — `description`, `maxLength`, `minItems`, `maxItems` are native JSON Schema, the Each's template binds → the array's `items` schema). An agent that discovers the component sees a rich, *required* schema — so it must gather real content (**Spatial** search) and hydrate the fields before it can render. The hydrated call's values flow back in as the component's state. **The schema IS the instruction channel**; there is no prompt to maintain anywhere else.
- **Grounding is part of the compiled contract:** fields are filled only from search results in the conversation — never invented. The compiler injects this law into every briefed schema.
- **The server referees and mirrors:** invalid/empty compositions are rejected with an instructive result before anything renders (the agent self-corrects and retries); a successful render returns *the page as the guest sees it* in the tool result, so the agent refines surgically on later turns ("more golf" knows which section to swap).
- **The single-face pattern pairs naturally:** a continuously-enriched page (one named face + `default` → the same face, no `inline`, no ✕) arrives in its surface, can never leave it, and each refinement turn merges new data into the same instance.
- Any number of briefed components can be live at once — each compiles to its own tool.

**Design edits the page; the page briefs the AI.** Changing a description or a length in the definition changes the agent's behavior on the next render — no prompt engineering, no redeploy.

---

## 🧩 Private steps — `states/` + `stateOrder`

A wizard's questions are the component's own states: one file per step in `states/`, listed in the envelope's `stateOrder` (the exact set, in order — **Studio**'s state picker and the mock walk use it):

```jsonc
"stateOrder": ["goals", "situation", "subject", "route", "mode", "commitment", "searching", "results"]
```

Inside a step, an option list is **hardcoded** `items` on an `Each`; picking an option writes the answer + the next step in one `setValue`:

```jsonc
{ "type": "Each",
  "items": [ { "value": "start", "label": "Start my career" }, … ],   // literal content
  "template": { "type": "Ref", "ref": "choice-row",
    "action": { "type": "setValue", "values": [
      { "key": "careerStage", "value": "{{value}}" },
      { "key": "step", "value": "situation" },
      { "key": "progressPct", "value": "33%" }
    ] } } }
```

⚠️ **A state never guards itself** — the root `Switch` (or the step `Switch`) already selects it; a `visibleWhen` re-checking the same discriminant inside a case is an error.

---

## 📋 Component checklist

- [ ] Flat if it can be — structure (`layouts/`, `states/`, manifest) is earned
- [ ] Manifest = render contract: arrival `defaultState` (open name) + discovery meta (no envelope duplicates)
- [ ] Root = `Switch on defaultState` → `layouts/<state>` (filename = state name); `default` case → inline
- [ ] Three homes respected: content hardcoded · `state` block scalar view-state only · `props` all `input: true`
- [ ] `stateOrder` names exactly the `states/` files
- [ ] Publish from Studio passes lint with 0 errors — every rule above is enforced

---

**Next:** [04 — State](./04-state.md) — how components and templates interact.
