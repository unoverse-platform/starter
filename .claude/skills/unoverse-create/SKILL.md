---
name: unoverse-create
description: Create or edit Unoverse platform artifacts — UI components (including briefed/AI-filled components), templates, atoms and styles (rx/), agent skills and prompt blocks (prompts/), custom workflow nodes (nodes/), and workflows built live on the Canvas via the builder MCP. Use when the user wants to create, add, build, or modify a component, template, theme, agent skill, prompt block, custom node, or workflow in an Unoverse starter repo.
---

# Creating Unoverse Artifacts

You are helping a developer build in the **Unoverse developer carve-out** — the three
editable folders mounted into the running platform:

| Folder | What lives there |
|---|---|
| `apps/unoverse/rx/` | **Design** (data, not code): components, atoms, org-scoped templates + styles |
| `apps/unoverse/prompts/` | **Behavior**: agent skills (`skills/`) + prompt blocks (`blocks/`) |
| `apps/unoverse/nodes/` | **Logic**: custom workflow nodes, authored as YAML |

## Step 1 — Identify the artifact, read its playbook

Decide what the user is creating, then **read the matching reference file before writing
anything**:

| The user wants… | Read |
|---|---|
| A UI component or shared atom — incl. a page/card the AI fills with content (briefed) | `references/component.md` (§Briefs for AI-filled) |
| A template / app layout (chat surface, wizard shell) | `references/template.md` |
| A style / theme / token change | `references/component.md` §Tokens |
| An agent skill (behavior guide the AI follows) | `references/agent-skill.md` |
| A prompt block (reusable prompt fragment) | `references/block.md` |
| A custom workflow node (integration, tool, logic) | `references/node.md` |
| A workflow (wire nodes into an agent/pipeline on the Canvas) | `references/workflow.md` |

Workflows are the one artifact that is NOT files: they are built live on the running
platform through the `unoverse-builder` MCP (registered by this repo's `.mcp.json`) —
the playbook covers the bind/build/test contract.

If it's ambiguous (e.g. "add a card that shows weather"), it's usually a **component**
(the UI) plus possibly a **node** (the data source) — confirm the scope with the user.

**New to design artifacts?** The guided learning journey at `docs/design/` (README →
quick-start → … → troubleshooting) teaches components, templates, the state model
(incl. locked voice/native state), tokens, Studio, and validation in order;
`docs/design/CLAUDE.md` is the condensed agent rulebook. The playbooks here assume that
material.

## Step 2 — Hard rules (apply to every artifact)

1. **Only edit the three carve-out folders.** Never touch, vendor, or work around the
   SDK, engine, or server — they are not yours to change. If a task seems to require an
   SDK change, the answer is almost always "express it as data" — re-read the playbook.
2. **Docs are the source of truth.** The playbooks point at `docs/design/` (the design
   journey), `docs/unoverse/` (deep reference), and `docs/nodes/` in this repo. When the
   user's request goes beyond the playbook, read the pointed doc section — do not
   improvise conventions.
3. **UI is data.** No pixels, hex colors, or CSS anywhere — token names only. No logic
   in definitions — anything computed (totals, formatting, chosen colors) is computed in
   the node and sent as a plain field.
4. **Audit before you're done.** Every component/template must pass the conformance
   checklist (`docs/unoverse/UNOVERSE_AUTHORING.md` §9). Walk it item by item.
5. **Discovery meta is ranked, not read.** Any spatially-discoverable artifact — a
   component or template with a manifest, an agent skill, a node — is selected by
   embedding `title`/`name` + `whenToUse`/`description` + `category` against the user's
   own words (or the planner's task). The strict contract is
   `docs/nodes/node-discoverability.md`: outcome-first, utterance-shaped, opening
   words dominate, disqualify by property (never name a sibling). Each playbook carries
   the summary; read doc 14 before writing any meta.

## Step 3 — Deploy loop (after the artifact is written)

Create a client org with `./unoverse new org <name>` (folder structure + default token
set). Components and templates have NO scaffold command — author them from the references
(mirror the closest existing artifact), and ALWAYS run `./unoverse lint` before deploying —
it enforces the schema, token law, and state rules with doc-cited messages (0 errors
required; justify any warning).

| Artifact | To see it live |
|---|---|
| Component / atom / template / style | `./unoverse lint`, then restart unoverse — nodes SYNTHESIZE from definitions (no codegen); deploy with `unoverse deploy design` |
| Existing component restyle/edit only | takes effect live (SDK reads `rx/` directly) |
| Agent skill / prompt block | `docker compose restart unoverse` |
| Node | `unoverse node lint`, then `unoverse node test <NodeType>`. No build: a node is YAML |

Verify with `./unoverse check` (services, node catalog, bundles). Preview components in
Studio: run `unoverse-studio` from the project folder, which opens on :4108.

> In the platform monorepo (not the starter), the node docs live at
> `packages/docs/nodes/`, the design journey at `packages/docs/design/`, and the dev loop
> is just `npm run dev` — component nodes synthesize from rx/ definitions at boot.
