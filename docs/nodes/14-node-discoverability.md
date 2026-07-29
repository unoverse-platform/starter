---
sidebarTitle: "Node Discoverability"
title: "Node Discoverability"
---

A node that works perfectly and never gets picked is dead code.

When the AI workflow builder assembles a workflow, it does not see every node you have. For
each step it asks for the nodes that suit the job, gets back a handful, and picks from those.
Your node is either in that handful or invisible.

Four fields decide it, and they all live in `node.yaml`.

```yaml node.yaml
name: Smart Document
category: Documents
description: Authors and revises a long document section by section
whenToUse: >-
  Pick whenever an Agent must author or revise a long document: a report, plan, spec,
  article or brief. Writes and revises section by section, so a one-shot generation
  cannot be revised and blows the context window on every change.
```

`whenToUse` is the one that matters. When it is present it **replaces** `description` for
matching, so it is not a footnote. It is the text being ranked.

## Write for the task, not for a reader

Before writing a word, write down the one-line task a planner would type for the job your
node does.

> "write a long report that the Agent can revise"

Those nouns and verbs are what your `name` and `whenToUse` have to match. If your opening
words are not in that sentence, your node loses to one whose are.

**The opening dominates.** A `whenToUse` that starts "Hybrid MCP node, attach via a service
edge…" is matched against wiring vocabulary rather than the job, so it ranks low and never
surfaces. Same node, same capability, invisible.

## The formula

Three layers, in this order.

**1. Outcome first.** Lead with the job in the words someone would use to describe it, not
the mechanism you built.

> Pick whenever an Agent must author or revise a long document: a report, plan, spec,
> article or brief.

**2. Disqualify yourself by property.** Say what makes your node right or wrong as a
property of the work, never by naming another node.

> Writes and revises section by section, so a one-shot generation cannot be revised and
> blows the context window on every change.

Naming a rival dates the moment a node is added or renamed, and it builds a web of
cross-references between nodes that all have to be maintained. Describe your own property
and let ranking surface the alternative.

**3. The wiring fact, last.** One sentence, and only if it is needed to work at all.

> Attach via a service edge to an agent node.

Keep it generic. Name the *kind* of consumer, "an agent node", not a specific node that will
be renamed later. The exception is a hard dependency: if your output must go somewhere
specific to be any use, name that.

Mechanism last, always. It is necessary for wiring and fatal for ranking when it leads.

## Category counts too

`category` is part of what gets matched, so pick the one that describes the **job**, not how
you built it. A node that produces a document is `Documents`, not `Agent Tools`, because the
second pulls it towards tool-plumbing vocabulary and away from the work.

The categories are: AI, Voice, Go To Market, Search, Web Scraping, Media & Design, Documents,
Knowledge & Vectors, Storage & Data, Communication, Flow, Output.

Add a new one only when a node's job genuinely fits none of them. Do not force-fit into a
catch-all.

## Anti-patterns

| Do not | Why |
|---|---|
| Lead with mechanism | "Hybrid MCP node…", "Callback node that…". Right words, wrong position, sinks the ranking |
| Name another node | Dates immediately, and describes their job rather than yours |
| Restate the description | "Use this node to call the Example API" carries no signal |
| Write marketing | "A powerful, flexible node for all your needs" |
| Describe the endpoint | "Calls GET /v2/companies/enrich with retry". Selection is on the job, not the URL |

## Before you ship

1. Write the one-line task a planner would type. Do its key words appear in your **first
   sentence**?
2. Which node wins that job today if yours did not exist? Did you sharpen the property that
   beats it, without naming it?
3. Is any wiring fact last rather than first?
4. Does `category` match the job the node does?
5. Is every claim true of what the node actually does?

Ranking uses what is published and accepted, so publish the node before expecting new
wording to change what gets picked.

## The same rule for templates and skills

Templates and agent skills are discovered the same way, with one difference that matters.

Nodes are matched against a **planner's task**, so "Pick when a step needs…" reads correctly.
Templates and skills are matched against **what a person actually said**, so write the words
they would use.

```yaml
# Wrong: instructions about the user, in developer vocabulary
whenToUse: Pick when the user asks to talk or wants a phone-style assistant.

# Right: the words a person would say
whenToUse: Talk to the assistant by voice, hands free, instead of typing.
```

**Beware the generalist trap.** A fallback surface that lists everything its siblings do will
outrank them for their own jobs. A fallback owns general help and questions, and cedes
specific jobs by property without naming them.

---

**Next**: [Testing](./13-testing-nodes.md)
