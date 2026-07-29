---
sidebarTitle: "MCP Services"
title: "MCP Services"
---

MCP is how an Agent gets tools. A node offers tools, an Agent node calls them, and the two
are joined by a service edge on the **Canvas**.

There are two sides to build, and they are separate jobs.

| You are building | Read |
|---|---|
| A node that **offers** tools to an Agent | [Offering tools](#offering-tools) |
| A node that **uses** tools, meaning an Agent | [Using tools](#using-tools) |

## Offering tools

Declare an `mcp` connector with `isService: true`, and list the tools by name.

```yaml interface.yaml
serviceConnectors:
  - name: mcpService
    description: Looks things up in the product catalogue
    serviceType: mcp
    isService: true
    methods:
      - findProduct
      - readProduct
    instructions: >-
      Search first with findProduct, then read the one you want with readProduct.
      Never guess an id.
```

Then write each tool in `api/service.yaml`, exactly as any other service method.

```yaml api/service.yaml
findProduct:
  description: Find products matching a search term.

  calls:
    - name: search
      method: GET
      url: https://api.example.com/products
      transport: json
      query:
        q: "{{ params.term }}"

  returns: "return response.items"
```

**`description` is what the Agent reads to decide whether to call it.** It is the tool's
selection text, so write what the tool achieves, not how it works. A vague description means
a tool that never gets picked, or gets picked for the wrong thing.

**`instructions` on the connector is different.** Each `description` says what one tool does.
`instructions` says how to use them well together, which is the thing no single tool
description can express. There is a section on writing it below.

**`params` is what the Agent passed.** Its shape comes from the tool's own inputs, so
validate what you rely on rather than assuming.

## Using tools

An Agent node consumes tools rather than offering them, so it declares the same
`serviceType` with `isService: false`.

```yaml interface.yaml
serviceConnectors:
  - name: mcpService
    serviceType: mcp
    isService: false
    description: MCP service connector, automatic schema discovery
```

Whatever is wired to that connector becomes the tool list. Nothing wired means no tools, and
the node should degrade to a single request rather than fail.

Then `api/toolExchange.yaml` describes how this API expresses a tool call.

```yaml api/toolExchange.yaml
$ref: tools

maxTurns: "{{ config.maxTurns }}"
stuckAfterRepeats: 3
```

**Declaring a `toolExchange` makes the node a `CallbackNode`**, because a tool loop is
multi-turn by definition. Lint enforces that.

### What the exchange describes

The platform counts the turns and runs the tools. The manifest describes the wire format,
because every API expresses the same idea differently.

| Key | Says |
|---|---|
| `tool` | how one tool is offered to the model |
| `toolsInto` | which request field the tool list goes in |
| `call` | how a tool call arrives, and how to read its id, name and arguments |
| `result` | how one result goes back |
| `resultsInto` | which request field results go in |
| `choice`, `choiceInto` | whether the model is free to pick |
| `continuity` | how one turn chains to the next |
| `maxTurns` | how many turns before it stops |
| `stuckAfterRepeats` | how many identical calls count as stuck |

That is a lot to write per node, so **put it in `shared/` once and `$ref` it**. Every node
for the same API imports the same protocol, and local keys layer on top.

```yaml
$ref: tools
maxTurns: 5
```

When the API changes how a function call is expressed, exactly one file changes.

### Two limits, and why both exist

`maxTurns` bounds how long the loop may run. Set it to 1 and the node answers in a single
pass and cannot call a tool at all.

`stuckAfterRepeats` catches a different failure. The same tool with the same arguments three
times is stuck, and `maxTurns` does not catch it, because a model calling many *different*
tools forever is not stuck by that rule.

## Writing instructions

`instructions` is appended to the Agent's system prompt, so it costs tokens on every turn.
Earn them.

**Not every node needs it.** Where the tool descriptions are self-sufficient, leave it out.
Include it when:

- the tools have a **sequence**, such as read, then edit, then retry
- which tool to reach for depends on **context**, such as a small edit against a full rewrite
- there are **anti-patterns** that waste calls or fail outright
- recovering from an error needs an order that no single description implies

**Five rules for writing it:**

1. **Do not repeat the tool descriptions.** Write the strategy between tools, not the tools.
2. **Be prescriptive.** "Always" and "never", not "consider".
3. **Give the reason for anything non-obvious.** "Never re-read after a stale error, because
   the error already carries the new hash" saves a wasted call.
4. **Show sequences.** The value is in the choreography, not the inventory.
5. **Keep it short.** Under a hundred lines, because it is in the prompt on every turn.

Instructions follow the same lifecycle as the tools they came with. Wired on the canvas, they
last the session. Discovered through **Spatial**, they are replaced when a new search returns
a different set.

Agent skills are a different thing, authored in `prompts/skills/` and discovered at run time.
`instructions` is part of the MCP schema and travels with the tools.

## When it goes wrong

| What you see | Why |
|---|---|
| The Agent never calls your tool | The `description` does not read like the job the Agent is trying to do |
| The Agent has no tools at all | Nothing is wired to the `mcp` connector |
| Lint: this must be a `CallbackNode` | It declares a `toolExchange`, which is multi-turn |
| The loop runs and runs | Check `maxTurns`, then `stuckAfterRepeats` |
| A tool returns but the workflow does not react | Expected. A service call returns to its caller and fires no outputs |

---

**Next**: [Connectors & Signals](./09-signal-routing.md)
