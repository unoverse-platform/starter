---
sidebarTitle: "Overview"
title: "Design Overview"
---

**Build cross-platform, server-driven UI (SDUI) as pure data — components and templates that render natively on every channel, streamed by real agents over MCP.**

You never write React, SwiftUI, or Compose. You write **neutral JSON definitions** in `rx/`, style them with **tokens**, drive them with a tiny **generic state model**, and view/test everything live in **Studio**. The platform turns each definition into a workflow node and serves it to every client as an **MCP App**.

The folder is called `rx/` for **Relationship Experience**: the interfaces you define here are how your brand's Agents meet people.

---

## 🎯 The Learning Journey

Work through these in order — each doc builds on the previous one.

### Getting Started
| Doc | What you'll learn |
|---|---|
| [01 — Quick Start](./01-quick-start.md) | Build your first component, validate it, deploy it, see it in **Studio** — in minutes |
| [02 — SDUI & MCP Apps](./02-sdui-and-mcp-apps.md) | The model: UI is data, the closed primitive set, why templates ARE MCP Apps |
| [02a — Coming from React](./02a-coming-from-react.md) | The translation table: every React/Flutter reflex → its Unoverse move |

### Core Concepts
| Doc | What you'll learn |
|---|---|
| [03 — Components](./03-components.md) | Contained microapps: the manifest render contract, `layouts/<state>` faces, the three homes for content |
| [04 — State](./04-state.md) | **The three buckets, the two writes, the four moves — and which state is locked (SDK/voice/native)** |
| [05 — Templates (MCP Apps)](./05-templates.md) | Template shells, `ComponentSlot`, `Timeline`, the manifest, `defaultState`, `whenToUse` |
| [06 — Styles & Tokens](./06-styles-and-tokens.md) | LAW 1 (own zero values), base → semantic → theme layers, org styles |

### Test & Ship
| Doc | What you'll learn |
|---|---|
| [07 — **Studio**](./07-studio.md) | View and test your work: mock states, live mode, multi-channel preview, state inspector |
| [08 — Validate & Ship](./08-validate-and-ship.md) | The JSON Schema, the guard linter, the conformance checklist, the deploy loop |
| [09 — Troubleshooting](./09-troubleshooting.md) | Symptom → cause → fix for the common mistakes |

**Building with an AI agent?** [CLAUDE.md](./CLAUDE.md) is the condensed rulebook an agent (or you, in a hurry) can follow end-to-end.

---

## 🧭 Quick Decision Guide

| I want to… | Build a… | Doc |
|---|---|---|
| Show a piece of streamed data (a card, a chart, a list) | **Component** — design-system tier (the installed marketplace package, org-neutral) or project tier (`rx/<project>/components/`, that org's own) | [03](./03-components.md) |
| Reuse a small piece across components | **Atom** (`rx/atoms/` — authoring-time only; the server expands it before serving) | [03](./03-components.md) |
| Define a whole surface (chat, voice, dashboard) | **Template** (`rx/<project>/templates/`) | [05](./05-templates.md) |
| Change colors / spacing / brand | **Tokens** (`rx/<project>/styles/`) | [06](./06-styles-and-tokens.md) |
| Make UI react (tabs, wizard steps, expand/collapse) | **State + the four moves** | [04](./04-state.md) |

---

## 📏 Key Principles

| Principle | Meaning |
|---|---|
| **UI is data** | Definitions are JSON. The SDK renderer is dumb and generic — it never knows your feature. |
| **Closed vocabulary** | A fixed set of primitives (`Box`, `Text`, `Switch`, `Each`, …). You compose; you never add primitives. |
| **Own zero values** | No `px`, no `#hex` in definitions — token names only. Rebrand = edit `styles/`, zero definition changes. |
| **The reaction contract** | A component writes only its own slice (`setValue`); templates react via state selectors (`select.where`); **inline is the universal default**. |
| **Locked state is read-only** | Conversation flow, voice call state, and native host chrome are managed for you — you project them, never manage them. |
| **MCP is the standard** | Templates are MCP Apps: definitions are MCP resources, sends are `tools/call`, answers are elicitations. No bespoke transport. |
| **Studio is the proof** | The dev loop IS the production loop — if it works in **Studio**, it works on every channel. |

---

## 🚀 Fast Path

```bash
# 1. Scaffold a conformant definition, then shape it (schema validates as you type)
# In Studio: New Project → "acme" — scaffolds rx/acme/ with the default token set

# 2. Lint (schema + token law + state rules, doc-cited messages), then deploy
# Validation runs in Studio: the schema as you type, the full lint at publish
./unoverse build

# 3. Open Studio and preview it with mock states, or live against a workflow
```

Start with [01 — Quick Start](./01-quick-start.md).
