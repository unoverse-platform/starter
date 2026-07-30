---
sidebarTitle: "Templates"
title: "Templates"
---

**A template is a set of LAYOUTS — full arrangements selected by the component views they're named after. Its manifest IS its envelope.**

Components render pieces; a **template** is the shell around them — the chat layout, the voice surface. It owns **nothing**: conversation and component data live in the store, so templates are swappable mid-conversation.

The connection between components and templates is **one rule**:

> **A component enters a view → the template presents the layout of the same name.**
> No matching layout → the default layout, and the component renders inline. Nothing is stored, nothing is wired — the names sync.

---

## 📁 The anatomy — manifest-only

```
rx/<project>/templates/acmechatlayout/
├── manifest.json        # THE ENVELOPE — everything about the app (below)
├── layouts/             # the ARRANGEMENTS — one per component view, + the default
│   ├── standard.json    #   the default (manifest.layout): the core chat alone
│   ├── products.json    #   a card entered "products" → core + the cards rail
│   └── product.json     #   a card entered "product"  → core + the detail panel
├── components/          # template-local partials (core, header, composer-bar, turns, …)
└── states/              # the template's LOCAL states (welcome, conversation, idle…)
```

There is **no `<name>.json`** — the manifest is the single contract file. Same folder grammar as components: a component is a Switch of **faces**; a template is a set of **layouts**. Each layout is a complete arrangement — typically `{ "$include": "components/core" }` plus that view's surface — so shared chrome lives once in `components/` and every layout includes it.

**Layouts vs. states — the rule of thumb:** *if a component causes it, it's a layout; if the template itself knows it, it's a state.* Local states (`welcome`/`conversation` on `hasMessages`, a voice layout's call phases on `callState`) branch **inside** whichever layout is showing, via the normal condition vocabulary ([04](./04-state.md)). A state is available in exactly the layouts whose trees include its file — the inclusion *is* the connection.

```jsonc
// manifest.json — the whole app in one file
{
  "name": "Acme Assistant",
  "description": "The Acme customer-support chat for questions about Acme products and services.",
  "whenToUse": "Ask Acme a question or get general guidance about its products…",   // utterance-shaped — selection text
  "category": "Assistant",
  "version": "1.0.0",
  "defaultState": "template",                     // the app's load state: "template" = the full surface
  "inputSchema": { "type": "object", "properties": { "message": { "type": "string" } } },
  "layout": "standard",                           // the DEFAULT layout (nothing surfaced)
  "stateOrder": ["welcome", "conversation", "products", "product"],   // states + layouts, in picker order
  "preview": { "products": ["productcard", "productcard"], "product": ["productcard"] },
                                                  // per-LAYOUT mock: what Studio seeds (repeat = several instances)
  "binding": { "workflow": "wf-8koixv", "trigger": "inputtrigger1" },   // the app OWNS its workflow
  "autoTrigger": false
  // a voice template adds: "service": "voice"  (the channel instantiates the native service)
}
```

A template with a **single** layout is simply always in it — the feature is invisible until you add a second file.

---

## 📐 Sizing — each layout owns its widths

> **The app is always the ACTIVE layout's total — nothing else, ever.**

Widths are declared with the neutral `appWidth` key, always a **named org size** from `styles/semantic/app-sizes.json` (`chat` · `chat-slim` · `rail` · `panel` — served on the theme, resolved by the SDK like any token). Two declaration points, both inside a layout:

```jsonc
// components/core.json — the chat column: a panel, always open, exactly `chat` wide
{ "type": "Box", "appWidth": "chat", … }

// layouts/products.json — the arrangement: core + the rail, whose surface declares ITS width
{ "type": "Box", "style": { "direction": "row", "width": "full", "height": "full", "overflow": "hidden" },
  "children": [
    { "$include": "components/core" },
    { "type": "ComponentSlot", "appWidth": "rail",
      "select": { "from": "all", "where": { "field": "defaultState", "eq": "products" } },
      "frame": { "type": "Box", "style": { "direction": "column", "overflow": "auto", … },
                 "children": [ { "type": "ComponentSlot" } ] } }
  ] }
```

So the width is one of a small known set by construction — the default layout is the core alone; a rail layout is core + rail; layouts can even use a different core (a slim call column beside a panel). The host animates between the totals; nothing inside ever resizes.

The rules (all lint-enforced):

- **Named sizes only.** Raw CSS in `appWidth` is an error — retuning a size is one edit in app-sizes.
- **One declaration per panel.** The panel's `appWidth` sizes its box *and* grows the app — a panel (or its frame) never declares `width`/`flex` of its own.
- **Never on a layout root.** The root is the arrangement; panels inside it carry the widths.
- **Never `visibleWhen`-guarded.** A conditional arrangement is a *layout*, selected by name — not a guarded pane.
- **An overlay declares nothing.** A surface rendered over the core (`inset: 0`) has no `appWidth` and needs no layout of its own — it never changes the app's size.
- Give every layout root `overflow: hidden` so a panel mid-slide clips at the edge instead of scrolling.

---

## 🧩 Template-only primitives

- **`Timeline`** — renders the conversation (you supply the `user`/`assistant` turn subtrees; per-turn scope carries `text`, `streaming`, …). The conversation bucket is locked to the stream ([04](./04-state.md)).
- **`ComponentSlot`** — where components render. Two forms:

```jsonc
// 1. the FLOW slot — components render inline in the conversation (the default home)
{ "type": "ComponentSlot", "select": {} }

// 2. a REACTION surface — presents whichever component is in a named view (§04)
{ "type": "ComponentSlot",
  "select": { "from": "all", "where": { "field": "defaultState", "eq": "product" }, "limit": 1 },
  "frame": { /* the surface chrome the selected component renders inside */ } }
```

Rules that bite:
- ✅ Surfaces select by the **view** (`where { field: "defaultState" }`) — ❌ never by component type, ❌ never by a component's internal state key. Both are lint-flagged.
- ✅ **A layout surfaces its own view.** A layout named `product` must contain a surface selecting `product` — the name claims the instance; the surface renders it (guard-enforced).
- ✅ **A surface's single occupant fills the surface.** A `limit: 1` surface gives its occupant the frame's full height automatically — zero per-face height styling. Multi-occupant surfaces (a rail) keep content-sized instances.
- ✅ **One instance → one placeholder.** While a component's view matches a layout/surface, it renders there — lifted out of the flow, never painted twice. Its own ✕ switches it back and it returns to the flow.
- ❌ Never size or restyle a component from the template — a component owns its faces ([03](./03-components.md)); the template owns only the framing.

**In-layout surfaces without a layout** are still normal: an overlay (e.g. a wizard in a focus overlay over the chat) lives inside the core, claims its view, and changes no width — it needs no layout file. Reach for a layout when the *arrangement* changes; keep a surface in-core when only a layer appears.

**Rich layers cap their height and scroll inside** (header/footer pinned, `flex: 1` + `minHeight: 0` + `overflow: auto` body).

---

## 🎙️ Voice templates

Declare `"service": "voice"` in the manifest; the channel instantiates the native service, which projects **`callState`** into scope. The call phases (`states/idle … states/user-speaking`) are LOCAL states, branching inside the layouts — typically a wide core in the default layout and a slim core in the card layouts, both including the same state files. Cards streaming in during a call select layouts by name exactly as in chat. Audio is never wired in a definition.

---

## 🤖 Naming & discoverability — how the AI picks the app

> **Canonical guide: `docs/nodes/14-node-discoverability.md`** — every rule there applies to
> templates and components verbatim, at *higher* stakes: apps are ranked against the
> **user's own words** (`findIntent`), not a planner's task query. Bad meta makes an
> entire app invisible. This section is the design-side summary.

**The formula.** **Spatial** embeds exactly `` `title. whenToUse||description [category]` ``
and ranks it against what the user literally types/says. Three consequences:
- **`whenToUse` IS the selection text** — when present it *replaces* description in the ranking.
- **The opening words dominate the embedding.** Lead with the user's vocabulary for the
  job; mechanism/layout words up front ("Two-column split: streamed text…") sink the app.
- Meta embeds **as-is** — no LLM rewrite. Editing it changes the content hash → re-embeds
  on the next train.

**One job per field — never blend:**

| Field | Job | Rules |
|---|---|---|
| `title` / `name` | human display name | short, the thing itself ("Bank Transfer") — no org prefix, no mechanism |
| `description` | what it **IS** | ONE line, ≤120 chars — the listing subtitle; no "use when…" inside it |
| `whenToUse` | the **selection text** | utterance-shaped, outcome-first, the user's own words |
| `category` | the **job's domain** | Payments, Travel, Assistant… — never the implementation |

**`whenToUse` rules:**

| | Example |
|---|---|
| ✅ Utterance-shaped, outcome-first | "Transfer or send money — pay a beneficiary or move funds." |
| ❌ Selector-shaped (dev framing) | "Pick when the user asks to book." — words no user ever types |
| ✅ Disqualify by property | "Not for data-dense monitoring." |
| ❌ Disqualify by naming a sibling | "Don't use if AcmeDashboard exists." — dates, tangles, poaches |

**The generalist trap.** A fallback/home surface must NOT enumerate its siblings' jobs
("ask about cards, transfers…") — that vocabulary outranks the focused apps for *their*
queries. A fallback owns *general help, questions, reaching a person*, and cedes specific
jobs by property, naming none.

**Cross-artifact collisions.** Own the modality or the job — a voice surface claiming
"asks to talk / speak to someone" poaches live-support intents. Cede the neighbor by
property.

**Self-test before shipping:** write the sentence a real user would say for this app's
job — do its nouns/verbs appear in your `whenToUse`'s FIRST sentence? Is the description
one plain line about what it is? Does the category name the domain, not the build?

---

## 📋 Template checklist

- [ ] Manifest-only: no `<name>.json`; `manifest.layout` names the default layout
- [ ] One layout per component view the app presents, each surfacing its own view; shared chrome in `components/`, included by every layout
- [ ] Widths: named app sizes only, on panels inside layouts — never raw CSS, never on a root, never `visibleWhen`-guarded
- [ ] Local states in `states/`, included by the layouts they apply to
- [ ] `binding.workflow` + `binding.trigger` real (the app owns them); `stateOrder` lists states + layouts in picker order; `preview` seeds each layout's mock
- [ ] Flow slot generic (`select: {}`); surfaces select by `where`, never `type`
- [ ] `whenToUse` utterance-shaped; `description` ≤120 chars
- [ ] Preview in **Studio** — layout pills × local states, then live ([07](./07-studio.md)); publish passes lint with 0 errors

---

**Next:** [06 — Styles & Tokens](./06-styles-and-tokens.md).
