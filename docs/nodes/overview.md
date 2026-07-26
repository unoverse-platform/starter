---
sidebarTitle: "Overview"
title: "Nodes"
---

A node is one step an Agent can take. It calls a service, shapes the answer, and passes it to
the next node in your workflow.

The node library in **Canvas** covers the common ground on day one. This section is for the
nodes only you can build: your own APIs, your own systems, the work that makes an Agent
yours.

A node is a folder of YAML. You describe the service you want to call, and the platform
performs it. There is nothing to compile and nothing to publish.

[Anatomy of a Node](./00-manifest-nodes.md) is the place to start.

## Documentation

### Getting started

| Page | Covers |
|---|---|
| [Anatomy of a Node](./00-manifest-nodes.md) | The folder, the five files, and how a call is described |
| [Node Types](./02-node-types.md) | Settling once or emitting many times, and how the platform tells |

### Building blocks

| Page | Covers |
|---|---|
| [Credentials](./04-credentials.md) | Authenticating against a real service |
| [Config Schema](./06-config-schema.md) | The settings form: every field type and how it renders |
| [Service Connectors](./07-service-connectors.md) | Handing a capability to another node |
| [MCP Services](./08-mcp-services.md) | Giving an Agent tools it can choose to call |
| [Signal Routing](./09-signal-routing.md) | Streaming, iteration, and waiting for the next signal |

### Ship it

| Page | Covers |
|---|---|
| [Discoverability](./14-node-discoverability.md) | Writing the words that decide whether the AI builder offers your node |
| [Testing](./13-testing-nodes.md) | Running a node against the real API before you wire it up |
| [Packages](./10-package-marketplace.md) | The envelope around a set of nodes |
| [Troubleshooting](./05-troubleshooting.md) | When a node loads but does nothing |

---

## The shape of a node

```
apps/unoverse/nodes/<package>/
├── package.yaml              # the package: category, the hosts it may call
├── credentials/              # the keys its nodes need
├── shared/                   # fragments several nodes reuse
└── nodes/
    └── YourNode/
        ├── node.yaml         # what it is
        ├── interface.yaml    # what it connects to
        ├── config.yaml       # the settings form
        ├── api/              # the call, and what leaves the node
        └── test.yaml         # a fixture you can run
```

One folder is one node. [Anatomy of a Node](./00-manifest-nodes.md) walks through every file.

## How you build one

1. Create the folder under a package's `nodes/`
2. Describe the node: `node.yaml`, `interface.yaml`, `config.yaml`
3. Describe the call: `api/request.yaml`, and `api/events.yaml` for what comes out
4. Add the host to the package's `egress`
5. Check it: `unoverse node lint`
6. Run it against the real service: `unoverse node test <NodeType>`

Save a file and the node reloads. No build, no registration, no publish.

## Nodes to learn from

The `openai` package covers every shape you are likely to need. Read the one closest to
yours before you start.

| Node | Read it for |
|---|---|
| **OpenAI** | The simplest case: one call, one answer |
| **OpenAI Stream** | Tokens arriving live, accumulated and throttled |
| **GPT-5 Structured Output** | A request whose shape changes with the settings |
| **Embedding Service** | A node other nodes call, rather than a workflow step |
| **OpenAI Agent** | A tool loop, and a second model narrating progress |

---

**Next**: [Anatomy of a Node](./00-manifest-nodes.md)
