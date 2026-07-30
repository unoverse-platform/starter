---
sidebarTitle: "Coming from React"
title: "Coming from React"
---

**Every instinct you have has a home here — it's just data now.**

SDUI feels alien for about a day, because your framework reflexes reach for code. This table is the mapping. The reason it must be data: one definition renders through **every** platform's SDK — web today; iOS, Android, React Native and Flutter as those SDKs land. Anything you could only express in code would fork per platform; data can't fork.

---

## 🔄 The translation table

| Your reflex | The Unoverse move | Doc |
|---|---|---|
| `useState(false)` for a toggle | A **dev-named key** the component writes into its own slice (`setValue`), read by `visibleWhen`. Template chrome (panels, draft) uses `setTemplateValue` | [04](./04-state.md) |
| `{isOpen && <Panel/>}` conditional render | `visibleWhen: { field: "openPanel", eq: "faq" }` (bare field name = truthy test) | [04](./04-state.md) |
| `switch`/ternary between views | `Switch` `on` one discriminant with `cases` | [04](./04-state.md) |
| `items.map(item => <Row/>)` | `Each` with `bind: { items: "items" }` + a `template` | [03](./03-components.md) |
| `onClick={() => setStep("confirm")}` | `action: { type: "setValue", values: [{ key: "step", value: "confirm" }] }` | [04](./04-state.md) |
| A shared `<Button/>` component | An **atom** in `rx/atoms/`, used via `Ref` — `props` remaps fields, `with` passes literals | [03](./03-components.md) |
| Splitting a big component into files | `$include` of `layouts/`/`states/`/`components/` siblings — but extraction is **earned**, not default | [03](./03-components.md) |
| CSS / styled-components / Tailwind values | **Semantic token names** only — `"padding": "lg"`, `"color": "text.primary"`. The values live in `rx/<project>/styles/` | [06](./06-styles-and-tokens.md) |
| `className="hover:shadow-md"` | `style: { hover: { "shadow": "md" } }` | [06](./06-styles-and-tokens.md) |
| Conditional classNames by state | `style.when: [{ field: "deltaPositive", eq: true, apply: { "color": "status.success" } }]` | [04](./04-state.md) |
| `const total = items.reduce(…)` in render | **Computed in the workflow node**, streamed as a plain field. Definitions have no expressions — by design | [03](./03-components.md) |
| `fetch()` / axios / your own WebSocket | Never. The SDK owns the one MCP path (`tools/call`, elicitation, `/stream`) | [02](./02-sdui-and-mcp-apps.md) |
| A context/store for "is the AI typing" | Locked — derived flags (`isStreaming`, `isEmpty`) are handed to you; project them | [04](./04-state.md) |
| Managing the mic / audio / call state | Locked — the SDK voice service owns audio; you branch a `Switch` on the projected `callState` | [04](./04-state.md) |
| A new widget library / npm UI package | No. Compose the **closed primitive set** — bars are `Box`+`Each`, an accordion is `visibleWhen` | [02](./02-sdui-and-mcp-apps.md) |

---

## 🧭 The three habit-breakers

Most confusion is one of these three, so name them up front:

1. **No expressions.** You cannot compute, concatenate, or compare beyond `eq`/`ne`/`in`/truthy. If you're missing a value, the workflow node sends it. This feels limiting for an hour and then becomes the feature: definitions stay verifiable, portable, and safe for an AI to write.
2. **No invented vocabulary.** Primitives are closed. Style **keys** are closed (the cross-platform contract — an invented key renders nowhere). Style **values** are token names. The linter and schema hold all three lines; when you hit a wall, the answer is composition or a token, not a new word.
3. **No plumbing.** State transport, streaming, voice, reconnection, turn identity — all locked inside the SDK and the MCP standard. You write what things look like and which keys they read; everything that moves data is someone else's (solved) problem.

---

**Why it's worth it:** the same file you write in [01 — Quick Start](./01-quick-start.md) is the file a Flutter user renders natively. There is no "port to mobile" project later — that's the entire bet of the platform.

**Next:** [03 — Components](./03-components.md).
