---
sidebarTitle: "Troubleshooting"
title: "Troubleshooting"
---

**Symptom → cause → fix.** Debug in **Studio**'s DevTools order: stream log → state inspector → definition ([07](./07-studio.md)). See the data before editing anything.

---

## Rendering

| Symptom | Cause | Fix |
|---|---|---|
| Component renders blank / shows defaults while data clearly streams | a `bind` doesn't match the streamed field name, or the prop has no default so partial data blanks it | check the **stream log** for the actual `COMPONENT_DATA` keys; align `bind`; give every prop a default |
| Definition edits do nothing | the change touched the component's **node** contract (props/meta), which needs a restart | `./unoverse build`, then re-check |
| Unknown type / element missing entirely | primitive typo, or an invented primitive | schema should have flagged it — wire the schema ([01](./01-quick-start.md)); compose from the closed set ([02](./02-sdui-and-mcp-apps.md)) |
| Style silently ignored | raw value (`12px`, `#fff`) or a token name that doesn't exist in the org's semantic set | tokens only; check `rx/<project>/styles/semantic/` for the real name; Studio's publish lint catches raw values |
| Looks right in one theme, broken in another | definition references a **base** palette entry, or the theme is missing a token | reference **semantic** names only; run the theme-contract guard |

## State & interactivity

| Symptom | Cause | Fix |
|---|---|---|
| `visibleWhen` never fires | key written to the wrong **bucket** (set with `setValue`, read from template state — or vice versa), or a key-name mismatch | open the **state inspector**; find where the key actually landed; align action and read ([04](./04-state.md) decision table) |
| Two views both visible / both hidden | N `visibleWhen`s with hand-negated conditions drifting apart | one `Switch` on one discriminant |
| Wizard step never changes | the case content self-guards with a stale condition, or the button writes a value no case matches | remove self-guards; check the exact string values in the inspector |
| Focus surface won't close | the component's ✕ isn't resetting ITS OWN state (or writes template state — the deprecated bridge) | the focused face carries its own ✕: `setValue { defaultState: "inline" }` on the component's slice; the surface's `where` selector un-matches and it closes ([04](./04-state.md)) |
| Thinking dots never stop bouncing | the turn's `WORKFLOW_COMPLETED` never arrived on the stream — a delivery problem, not your definition | verify in the stream log, then report it; ❌ never gate the indicator on component text as a workaround |
| Voice template stuck in one phase | branching on raw booleans instead of `callState`, or reading it from the wrong scope | `Switch` on the single `callState` value in template scope ([04](./04-state.md)) |

## Templates & selection

| Symptom | Cause | Fix |
|---|---|---|
| A focus panel shows the wrong / a stale component | the surface selects with no `where` (bare `from: "all"` is oldest-first) | select by state: `where: { field: "defaultState", eq: "focused" }, limit: 1` — most recent state-write wins ([05](./05-templates.md)) |
| The AI never picks your component/template | `whenToUse` is layout-first or missing | rewrite outcome-first in the user's vocabulary ([05](./05-templates.md)) |
| A wide component gets squashed / a card gets stretched | template is imposing sizes on components | delete the template rule; the component declares its own size in its definition |
| Template swap loses the conversation | template is holding data it shouldn't — state lives in the store, templates own nothing | move the data to the proper bucket; templates only project |

## Pipeline

| Symptom | Cause | Fix |
|---|---|---|
| New definition rejected at boot | invalid definition JSON, or an envelope the schema rejects | run the ajv sweep from [08](./08-validate-and-ship.md); fix the reported file |
| Component exists in **Studio** but not on the **Canvas** palette | the platform didn't restart / register | `./unoverse build`, then `./unoverse check` |
| Mock states don't appear in **Studio**'s picker | the definition has no `states/` folder — the folder IS the picker; single-file definitions list nothing | enumerate each layer as `states/<layer>.json`; pills appear automatically, ordered by the root's `$include` sequence |

---

**Stuck beyond this?** Re-read the relevant concept doc — most persistent bugs are model misunderstandings (wrong bucket, template owning what a component owns, logic in the definition), not typos.
