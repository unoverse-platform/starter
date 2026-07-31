# Playbook — Components & Atoms (rx data)

**Read first:** `docs/design/components.md` (the microapp anatomy) + `docs/design/state.md`
(the reaction contract). Deep law: `UNOVERSE_AUTHORING` §3 (three homes),
`UNOVERSE_STATE_MODEL.md` §5b. **Study the exemplars before writing**: `rx/components/journeyfinder`
and cardfinder — mirror them exactly.

## The anatomy

```
apps/unoverse/rx/components/<name>/            # DESIGN SYSTEM tier (generic, universal)
apps/unoverse/rx/orgs/<org>/components/<name>/ # ORG tier (the client's own microapp, org-private)
  <name>.json      # envelope: name/category/nodeSize/outputs/props/state/stateOrder/root
  manifest.json    # RENDER CONTRACT: arrival defaultState (open name, default "inline")
                   #   + discovery meta (title / description ≤120 / whenToUse utterance-shaped).
                   #   Presence = spatially discoverable; envelope NEVER duplicates the meta.
  layouts/         # the FACES — filename = state name: inline.json, focused.json, (custom).json
  states/          # the component's PRIVATE steps (wizard questions) — listed in stateOrder
  components/      # component-local shared partials (earned: 2+ states share a shape)
```

A **flat component** (simple card/chart) is just `<name>.json` + `root` — one face, no manifest,
no folders. Structure is EARNED; start flat.

## The rules (lint enforces all of these — 0 errors required)

1. **Three homes for everything it shows** (AUTHORING §3):
   - static content → **hardcoded literals** in the layout (`value`, literal `items: []` on
     Each, `src`) — never props, never `state`;
   - internal view-state → the **`state` block, SCALARS ONLY** (`step`, `phase`,
     `progressPct`) — an array/object/URL in `state` is slop (workflow data → props;
     static → hardcode);
   - workflow-fed data → **`props` with `input: true`** (the `default` is the preview mock).
     Usually empty.
   - **Prop names = the data contract — never invent them.** Source data hydrates props
     BY NAME (as-is, no mapping); a name the source doesn't carry silently renders the
     preview default (tell: title streams, image stays mock). Content-attached cards use
     the writer vocabulary: `title` `tagline` `description` `bodyCopy` `introParagraph`
     `primaryImage` `images` `link` `callToAction`. Guard:
     `server/src/runtime/content-card-hydration.test.ts`; law:
     `UNOVERSE_MCP_TEMPLATE_PROTOCOL.md` §Content-attached cards.
2. **Root = `Switch on defaultState`** — the component is a switch of **views**, ONE active.
   Cases `$include layouts/<state>` (filename = view name); `default` → the inline layout.
   Arrival view = **manifest.defaultState**. Keep an `inline` case for any component that
   lives in a conversation flow — it is its placeholder there. EXCEPTION — the
   **single-face (permanent) component**: exactly ONE named view + `default` pointing at
   the SAME face, NO inline. It arrives in its surface, cannot leave it (no ✕, no other
   view), and is enriched in place via data merges to one stable instance — e.g. a
   continuously-updated page living in a template's focus surface. Permanence is by
   construction, never by a pinning rule.
   **Lifetime (OPTIONAL manifest flag)** — `"lifetime": "conversation"` marks a durable,
   conversation-scoped surface (a cart, an itinerary, a composed page): the platform keys
   its instance by the CONVERSATION (every re-call hydrates the SAME slice — merge, not
   re-place) and the new-turn reset skips it, so it stays on screen until it is replaced,
   closes itself, or a NEW TEMPLATE loads (the template swap is the hard refresh boundary).
   Default `"turn"`: the instance returns to inline / retires on the next user turn.
   Values are a closed set — `turn | conversation` (lint-checked; docs/design/04).
3. **State is local; the VIEW is the interface** (STATE_MODEL §5b). Internal `state`
   (`step`, `phase`, …) is the component's own business — the template never sees it. The
   only thing that crosses to the template is the **active view** (`defaultState`). The
   component writes ONLY its own slice (`setValue`): expand = `setValue { defaultState:
   "course" }`; its expanded face carries its own ✕ back to `"inline"`. When a template has
   a surface for that view, the instance **lifts out of the flow into the surface** — the
   SDK renders each instance in exactly ONE placeholder, so you never hide a flow copy
   yourself (no `hideBelow`, no overlay hack). ❌ NEVER `setTemplateValue` to open a surface
   (the deprecated bridge — linted).
4. **`stateOrder`** names exactly the `states/*.json` files, in order.
5. **Atoms** (`rx/atoms/`, via `Ref`) are for shapes shared across components — authoring-time
   only (the server expands them before serving; no Studio view). `Ref props` remaps FIELDS;
   **`Ref with` passes LITERALS**: `{ "type": "Ref", "ref": "button", "with": { "label":
   "Learn more", "icon": "arrowRight" }, "action": { … } }` — a bind whose field is a `with`
   key becomes a hardcoded attribute, a truthy `with` key drops a matching `visibleWhen`
   guard (unprovided ⇒ that piece stays hidden), `{{key}}` style bindings take the value.
   ⚠ Icon: literal = `icon: "phone"`; bound = `bind: { name: field }`.
6. **Briefs — components an AI fills** (docs/design/03 §Briefed components; deep law: `UNOVERSE_AUTHORING` §3b). A `brief`
   sits ON the node that renders what it describes, next to its `bind` — never in the
   manifest, never a separate file:
   - bound element → `"brief": { "description": "…", "maxLength": 60 }`
   - Each → `"brief": { "description": "…", "minItems": 3, "maxItems": 5 }` (its template's
     binds define the item shape — brief those fields too)
   - face/partial ROOT (no bind) → a plain-string brief = composition context
     (ordering, refinement rules like "update, never discard").
   The platform compiles briefs into the component's MCP tool schema (keys pass through
   verbatim — the brief uses JSON Schema's OWN vocabulary) and injects the grounding law (fill ONLY from
   spatial search results — never invent). The server REFEREES (invalid/empty args →
   instructive result, no render) and MIRRORS (success result returns the rendered page
   for surgical refinement). **The schema IS the instruction channel** —
   write briefs, never side-channel prompts/skills for filling a component. Shape is
   closed + linted. Pairs with the single-face permanent pattern (rule 2) for
   continuously-enriched pages; exemplar: `rx/components/perfectday`.
7. **Tokens only** (LAW 1) + closed style keys + real space-scale steps
   (`docs/design/06`) — an invented step is silently broken CSS.
8. **Lifecycle handlers — a component's own server-side code** (deep law:
   `UNOVERSE_AUTHORING` §3c). When a component needs live data from an
   API or a computation (not from an AI = brief, not from the workflow = `input` props), it
   may bring a small server-side script that runs when the component renders. It's for DATA,
   not styling or logic-in-the-def.
   - **Opt in via the manifest** (authorizes execution; auditable): `"lifecycle":
     ["onStart"]` in `manifest.json`. A handler file with no opt-in is INERT.
   - **The code is a sibling file named for the lifecycle** — `onStart` → `onstart.js`,
     beside `<name>.json`. Its **default export** is the handler.
   - **`onStart`** is the only lifecycle today; it runs SERVER-SIDE when the instance is
     created (the MCP render path), and whatever it returns is **merged into the instance
     by prop name** (unknown keys inert — same contract as workflow-fed props). Return only
     the fields you're filling; **never overwrite a curated prop** you didn't intend to.
   - **`ctx` is a bounded sandbox**: `ctx.props` (the instance's current data),
     `ctx.instanceId`, `ctx.env(name)` (server config). The **API key comes from
     `ctx.env`, NEVER hardcoded** — `rx/` is a shared design folder; a secret in it leaks.
   - Self-contained (the external call lives in the handler); errors never break the render.
   Exemplar: `rx/orgs/yasisland/components/restaurantcard/onstart.js` (Google Maps details).

   ```js
   // onstart.js — manifest opts in with "lifecycle": ["onStart"]
   export default async function onStart(ctx) {
     const key = ctx.env("SEARCHAPI_KEY");                 // secret from server config
     const res = await fetch(`https://…&q=${encodeURIComponent(ctx.props.title)}&api_key=${key}`);
     const place = (await res.json()).local_results?.[0] ?? {};
     return { rating: place.rating, address: place.address };   // merged by prop name
   }
   ```

## Discovery meta — write it to RANK (docs/nodes/node-discoverability.md)

A component with a manifest is an **MCP app**: spatial embeds `` `title. whenToUse||description
[category]` `` and ranks it against the USER'S OWN WORDS (`findIntent`). The meta is the
selection text, not documentation — weak meta makes a working component invisible. The
strict contract (doc 14, applies verbatim):

- **`title`** = the thing itself, human display name — no mechanism, no org prefix.
- **`description`** = what it IS, ONE line ≤120 chars — the listing subtitle; never
  "use when…" inside it.
- **`whenToUse`** = the selection text, **utterance-shaped**: the words a user would
  actually say, outcome first — the OPENING words dominate the embedding. Never
  selector-shaped dev framing ("Pick when the user asks…"), never layout/mechanism first
  ("A single-face page that…" ranks near rendering concepts and loses every intent query).
- **Disqualify by PROPERTY, never by naming a sibling** ("Not for answering a single
  question, not for one item on its own") — naming rivals dates and tangles; the ranking
  surfaces the alternative. A fallback/home surface never enumerates siblings' jobs
  (the generalist trap).
- **`category`** = the domain of the JOB (Travel, Payments…), not the implementation.
- Meta embeds **AS-IS** (no LLM rewrite); editing `whenToUse` re-embeds on the next train.

Self-test before shipping: write the sentence the user would actually say to want this
component — its key nouns/verbs must appear in `whenToUse`'s first sentence.

## Workflow

1. Study the closest exemplar; copy its folder shape.
2. Write the envelope + manifest + layouts; put every shown thing in its ONE home.
3. `./unoverse lint` — 0 errors (it cites the doc for every rule).
4. Restart unoverse → Studio: mock (prop defaults + state picker + Inline/Focused
   toggle), then live. Debug: stream log → state inspector → definition; never guess.
