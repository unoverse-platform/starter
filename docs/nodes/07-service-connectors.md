---
sidebarTitle: "Service Connectors"
title: "Service Connectors"
---

Most nodes pass data along a workflow. Some instead offer a capability that other nodes call
on demand, like turning text into a vector.

A service connector is that arrangement. One node offers, another calls, and they are joined
by a service edge on the **Canvas** rather than a data edge.

## Two channels, and they never cross

A node has two ways of being triggered, and it is worth keeping them apart.

| Channel | Triggered by | Produces |
|---|---|---|
| Workflow | the graph reaching the node | emits on its output connectors |
| Service | another node calling a method | returns a value to that caller |

A service call **returns to its caller** and fires no output connectors. Nothing leaks from
one channel into the other.

A node can have both. A node that only ever answers other nodes has no inputs and no outputs
at all.

## Offering a service

Declare the connector in `interface.yaml`, with `isService: true` and the methods you offer.

```yaml interface.yaml
serviceConnectors:
  - name: embeddingService
    description: Provides embedding generation services
    serviceType: embedding
    isService: true
    methods:
      - createEmbedding
      - createBatchEmbeddings
```

Then write the methods in `api/service.yaml`, keyed by name.

```yaml api/service.yaml
createEmbedding:
  description: Embed one piece of text and return its vector.

  calls:
    - name: embed
      method: POST
      url: https://api.example.com/v1/embeddings
      transport: json
      credential:
        scheme: bearer
        token: "{{ credentials.exampleCredential.apiKey }}"
      body: >-
        return { model: config.model, input: params.text }

  returns: "return response.data[0].embedding"
```

Three things to notice.

**`params` is what the caller passed.** A method reads its arguments there, the way a call
reads settings from `config`.

**`returns` says what the caller gets back.** It is `returns` rather than an events table,
because a service call hands back one value and emits nothing.

**A method's calls are a list**, the same shape as `api/run.yaml`. A method needing two
requests is the same idea as a node needing two.

Every method name in `service.yaml` must appear in the connector's `methods` list, and lint
checks that they agree.

## Consuming a service

Declare the same `serviceType` with `isService: false`. The node now accepts a service edge
from any node that provides it.

```yaml interface.yaml
serviceConnectors:
  - name: embeddingService
    serviceType: embedding
    isService: false
    methods:
      - createEmbedding
```

On the **Canvas**, drag from the provider's `service` handle to the consumer's
`serviceConsumer` handle.

Whether anything is wired is a run-time fact, and templates read it through the `services`
root. That is how a node adapts to what it was actually given.

```yaml
body:
  tools: "{{#if services.mcpService.tools}}...{{/if}}"
```

Nothing wired should still work. Degrade to the simple path rather than failing.

## Service types

There are two.

| `serviceType` | For |
|---|---|
| `embedding` | turning text into vectors |
| `mcp` | tools an Agent can choose to call |

`mcp` is the larger of the two and has its own page: [MCP Services](./08-mcp-services.md).

A provider may also carry `instructions`, which tell an Agent how to use its tools well
together. That is strategy, and it is separate from the description of each method.

## When it goes wrong

| What you see | Why |
|---|---|
| Lint: a method is missing from the connector | `service.yaml` and `methods` have drifted apart |
| The consumer sees nothing | Nothing is wired, or the provider offers a different `serviceType` |
| The provider runs but nothing reaches the workflow | Expected. A service call returns to its caller and fires no outputs |
| A pure service node never triggers | Also expected. It has no inputs, so the graph never reaches it |

---

**Next**: [MCP Services](./08-mcp-services.md)
