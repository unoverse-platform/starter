# Playbook — Agent Skills (prompts/skills)

An agent skill is a markdown behavior guide the platform's AI agents discover and follow
at runtime (e.g. how to handle complaints, how to walk a user through a process). It is
**prose for an agent**, not code.

## Where files go

```
apps/unoverse/prompts/skills/<skill-name>/
  SKILL.md           # required — frontmatter + instructions
```

The runtime scans this folder and serves skills to agents; agents match on the
`description` and `triggers`.

## SKILL.md format

```markdown
---
name: skill-name                # required: lowercase, numbers, hyphens; max 64 chars
title: Skill Name               # human display name — shows as the item's title in listings
description: What this skill IS — ONE short line (≤ 120 chars), the listing subtitle
whenToUse: The SELECTION text — outcome-first, in the user's vocabulary; ranked against intent for spatial discovery. See docs/nodes/node-discoverability.md — the node rules apply verbatim.
version: 1.0.0                  # optional, semver
category: ai                    # optional: ai | integration | workflow | utility
triggers:                       # optional, max 20 keywords/phrases (2–50 chars each)
  - keyword or phrase
credentials: []                 # optional: credential types the skill's flow needs
nodeTypes: []                   # optional: workflow node types the skill relies on
---

# Skill Name

## When to Use This Skill
[The situations that should activate this behavior]

## Approach / Instructions
[Clear, step-by-step guidance. Concrete do/don't phrasing beats abstractions —
include example lines the agent can use verbatim where tone matters.]

## Examples
[Concrete before/after or dialogue examples]
```

Stick to the keys above. The markdown body must exist — a skill with frontmatter only
is invalid.

## Writing rules

1. **`whenToUse` does the routing; `description` says what it is.** Never blend them
   into one field. `whenToUse` is embedded and ranked against user intent (spatial
   discovery / findIntent) — write it **outcome-first in the user's vocabulary**
   ("Handle an unhappy customer — a complaint, frustration, or a request to
   escalate…"), never mechanism-first. The full rules are
   `docs/nodes/node-discoverability.md` — they apply to skills verbatim.
2. **Study an existing skill** in `prompts/skills/` and match its voice and structure.
3. Keep instructions outcome-focused and scannable: short sections, bulleted do/don't
   lists, explicit escalation/stop conditions.
4. One skill = one behavior. If you're writing "and also…", split it.

## Ship

`docker compose restart unoverse` — the runtime rescans skills at boot. Verify the
skill appears via the platform's skill listing (`./unoverse check` for overall health).
