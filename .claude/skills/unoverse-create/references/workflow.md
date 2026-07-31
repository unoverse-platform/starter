# Playbook: Build a workflow (via the builder MCP)

Workflows are NOT files in the carve-out — they live in the platform and are built
through the **builder MCP** (`canvas`, auto-registered by this repo's
`.mcp.json`). You drive the platform's own authoring tools; the canvas updates live
in the developer's browser as you build.

## Prerequisites (check before starting)

1. **The platform is running** (`./unoverse start`, or `npm run dev` in the platform
   repo). The builder listens on `localhost:4106` — local machine only, by design.
2. **The MCP is connected**: `canvas` should show connected with 14 tools.
   If it shows failed, the platform wasn't up when the session started — reconnect
   via `/mcp` after starting it.
3. **The developer gives you a pairing code.** Ask them to open a **new empty
   workflow in Canvas** (http://localhost:3001), click **"Connect agent"** in the
   toolbar, and paste the short code it shows (e.g. `FW9D-6QKA`). The code binds you
   to that one workflow — single use, expires in 10 minutes. There is deliberately no
   way to list or discover workflows from here — the code must come from the developer.
   Prefer a fresh workflow: saves are provenance-scoped, so wiring into nodes you
   didn't create may be rejected.

## The contract

1. **`bindWorkflow` first.** Every other tool refuses until the session is bound,
   and every call after is pinned server-side to that one canvas.
2. **Read the in-band guides before building.** The deep how-to is served by the
   platform itself via `readBuilderSkill` — always current, never duplicated here:
   - `solution-design` — read FIRST on any new goal
   - `workflow-building` — the build protocol + response-field semantics
   - `workflow-testing` — runTest / stepNode / reading traces
   - `template-references` — the `{{...}}` grammar + fixing lint errors
3. **Build ONE stage at a time.** The loop is: `saveWorkflow` one stage → `runTest`
   → read the trace → add the next stage based on that evidence. Never design or
   pre-wire the whole graph up front — you learn a node's real output fields by
   running it, not by planning.
4. **Ground truth rules:** `getCanvas` is the real graph; a nodeType is valid only
   if `getNodeCatalog` returned it (search it fresh per step, with a one-line
   `task`); layout and node ids are not yours to set.
5. **The developer judges the result — never self-certify.** When the workflow runs
   end-to-end with real, non-empty output, report what you built and what the test
   showed. They watch the canvas live and accept, or ask for changes (which continue
   on the same bound canvas).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Every tool returns "No workflow bound" | Call `bindWorkflow` with the pairing code from Canvas "Connect agent" |
| Bind fails "invalid or expired pairing code" | Codes are single-use + 10-min TTL — ask the developer to click "Connect agent" again for a fresh one |
| Tool calls error after working earlier | The platform restarted mid-session — `/mcp` → reconnect |
| saveWorkflow rejects an edge into an existing node | Provenance guard: that node wasn't built this session — build on a fresh workflow, or recreate the stage yourself |
