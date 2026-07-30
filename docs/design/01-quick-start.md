---
sidebarTitle: "Quick Start"
title: "Quick Start"
---

**Build your first component, validate it, deploy it, and see it render in Studio.**

No React. No build config. One JSON file.

---

## 🎯 What you're building

A `PriceCard` component: a card that shows a product name, a price, and a short description, streamed to it by any workflow. It will render natively on web (and every other channel) from the same definition.

---

## Step 1 — Scaffold, then shape the definition

> Throughout these docs, `rx/` means the design folder in your repo: **`apps/unoverse/rx/`**. It is mounted straight into the running platform.

```bash
# In Studio: New Project → "acme" — scaffolds rx/acme/ (components/, templates/,
# and a complete copy of the default token set in styles/)
```

This creates `rx/components/pricecard/pricecard.json`, already passing the linter — you fill the TODOs and shape the tree. Edited for our card:

```jsonc
{
  "unoverse": "1.0",
  "kind": "component",
  "name": "PriceCard",
  "category": "Commerce",
  "description": "A card showing a product name, price and short description.",
  "whenToUse": "Show a single product or plan with its price. Not for lists of products (use a list component) or for charts.",
  "props": {
    "title":       { "type": "string", "default": "Pro Plan", "input": true },
    "price":       { "type": "string", "default": "$29/mo", "input": true },
    "description": { "type": "string", "default": "Everything in Basic plus priority support.", "input": true }
  },
  "root": {
    "type": "Box",
    "style": { "width": "full", "direction": "column", "gap": "3", "padding": "lg",
               "background": "surface.base", "border": "subtle", "shadow": "lg" },
    "children": [
      { "type": "Text", "bind": { "value": "title" },
        "style": { "font": "headline.sm", "weight": "semibold", "color": "text.primary" } },
      { "type": "Text", "bind": { "value": "price" },
        "style": { "font": "headline.lg", "color": "text.primary" } },
      { "type": "Text", "bind": { "value": "description" }, "visibleWhen": "description",
        "style": { "font": "body.md", "color": "text.secondary" } }
    ]
  }
}
```

What each part is:

| Field | Role |
|---|---|
| `unoverse` / `kind` / `name` | The **envelope** — marks this file as a component definition |
| `whenToUse` | **Required for components** — the AI reads this to pick your component. Outcome-first, in the user's vocabulary. See [08](./08-validate-and-ship.md) |
| `props` | The **data contract** — every field the definition reads, with a default (the **Studio** mock). `input: true` = fed by the workflow at runtime — mark **all** workflow-fed props |
| `root` | The UI tree, built only from **primitives** ([02](./02-sdui-and-mcp-apps.md)) |
| `bind` | An object mapping the primitive's target → your data field: `{ "value": "title" }`, `{ "src": "image" }` |
| `visibleWhen` | A bare field name is a truthy test — the description row hides when empty |
| `style` values | **Token names only** — `"3"`, `"surface.base"`, `"headline.sm"`. Never `12px` or `#fff` ([06](./06-styles-and-tokens.md)) |

---

## Step 2 — Validate as you type

The JSON Schema at `rx/_schema/unoverse.schema.json` catches structural mistakes (unknown primitive, missing `whenToUse`, a `Switch` without `cases`, an illegal condition) **in your editor**. Wire it once in `.vscode/settings.json`:

```jsonc
{
  "json.schemas": [
    {
      "fileMatch": ["**/rx/**/components/**/*.json", "**/rx/**/templates/**/*.json", "**/rx/**/atoms/*.json"],
      "url": "./apps/unoverse/rx/_schema/unoverse.schema.json"
    }
  ]
}
```

Now a typo like `"type": "Bax"` or a missing `description` is a red squiggle, not a runtime surprise. [08 — Validate & Ship](./08-validate-and-ship.md) covers the full enforcement stack (schema → linter → checklist).

---

## Step 3 — Mock data & states for Studio

Two mechanisms, both already in your file:

- **Prop `default`s ARE the mock.** Studio renders the component from them with no backend — that's why every prop carries a realistic default, not an empty string.
- **The `states/` folder is the state picker.** If your component has multiple layers (a `Switch` on a discriminant — wizard steps, inline↔focused), enumerate each layer as `states/<layer>.json` and **Studio** automatically shows a pill per state; clicking one sets the discriminant and that layer draws itself ([07](./07-studio.md)). PriceCard is single-view, so it needs none.

---

## Step 4 — Lint, then deploy

```bash
# Validation is Studio's job: the schema checks as you type; the full lint
# (tokens, state rules, structure) runs at publish and blocks on any error
./unoverse build    # nodes synthesize from your definitions at boot
```

Component nodes are **definition-backed**: one universal executor serves every component, and the platform synthesizes a node per definition at boot — there is no code generation. The restart just picks up your new definition. Your `PriceCard` is now:

- a **node** any workflow can use — copy it from **Studio** (**⧉ Copy for Canvas**) and paste (`Cmd+V`) onto the **Canvas**, wire data into its props — and
- an **MCP resource** every channel (web, native, **Studio**) renders natively.

---

## Step 5 — See it in Studio

Open **Studio** (served by the platform — see [07 — **Studio**](./07-studio.md)):

1. Find **PriceCard** in the component list.
2. **Mock mode**: it renders from your prop defaults; multi-state components get a state picker from their `states/` folder — this is your Storybook.
3. **Live mode**: wire it into a workflow on the **Canvas** and watch a real agent stream real data into it.

If it looks right in **Studio**, it looks right in production — **Studio** is just another MCP client using the same SDK and the same stream ([02](./02-sdui-and-mcp-apps.md) explains why).

---

## 📋 Quick-Start Checklist

- [ ] Project created in Studio (New Project); component authored in it with a full envelope
- [ ] `whenToUse` written outcome-first (the AI picks components by it)
- [ ] Every `bind` has a matching prop **with a default**, workflow-fed props marked `input: true`
- [ ] Zero raw values — token names only in every `style`
- [ ] Prop defaults realistic (they ARE the mock); multi-layer components enumerate `states/`
- [ ] Studio preview clean (mock, then live); publish passes lint with 0 errors
- [ ] Previewed in **Studio** (mock states, then live)

---

**Next:** [02 — SDUI & MCP Apps](./02-sdui-and-mcp-apps.md) — the model behind what you just did.
