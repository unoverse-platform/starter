---
sidebarTitle: "Overview"
title: "Nodes"
---

A node is a service you drag onto the **Canvas**. It connects an Agent to another system.

There is a marketplace of nodes. When none of them suits your situation, you build your own,
and this section is about building one.

<Tip>
**Check the marketplace first.** It ships with a library of ready-made nodes covering AI, Voice, Go To Market, Search, Web Scraping, Media & Design, Documents, Knowledge & Vectors, Storage & Data, Communication, Flow and Output. Adding one takes a click, and most of what an Agent needs is already there.
</Tip>

A node you build is a folder of YAML files. You describe the API call, and the platform
makes it.

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
| [Who Can Run It](./15-who-can-run-it.md) | Requiring a role before your node runs |
| [Config Schema](./06-config-schema.md) | The settings form: every field type and how it renders |
| [Service Connectors](./07-service-connectors.md) | Handing a capability to another node |
| [MCP Services](./08-mcp-services.md) | Giving an Agent tools it can choose to call |
| [Connectors & Signals](./09-signal-routing.md) | Wiring nodes together, and putting values on an output |
| [Beyond One Request](./12-calls-that-loop.md) | Paging, batching, waiting on a job, remembering, and sockets |

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
├── package.yaml
├── credentials/
├── shared/
└── nodes/
    └── YourNode/
        ├── node.yaml
        ├── interface.yaml
        ├── config.yaml
        ├── api/
        │   ├── run.yaml
        │   ├── events.yaml
        │   └── service.yaml
        └── test.yaml
```

One folder is one node. The package around it holds anything its nodes share.

| File | What it does |
|---|---|
| `package.yaml` | Names the package and lists the hosts its nodes may call. A call to anywhere else is refused |
| `credentials/` | The credentials its nodes ask for. The shape of each one, never a value |
| `shared/` | Fragments more than one node reuses, such as a base URL or a list of models |
| `node.yaml` | What the node is: its name, colour, and the words that decide when an Agent picks it |
| `interface.yaml` | What it connects to: its inputs, its outputs, and the credentials it needs |
| `config.yaml` | The settings form someone fills in on the **Canvas** |
| `api/` | What the node calls, what comes out, and what it offers to other nodes |
| `test.yaml` | Sample settings and inputs, so you can run the node for real before wiring it up |

Only `node.yaml` is required. A small node can hold everything in that one file.

### Inside `api/`

One file per job, and a node uses the ones it needs.

| File | What it does |
|---|---|
| `run.yaml` | The calls the node makes when the workflow triggers it |
| `events.yaml` | Everything that leaves the node, one row per output connector |
| `service.yaml` | Methods this node offers to other nodes over a service edge |
| `toolExchange.yaml` | The protocol for a node that lets a model call tools over several turns |
| `narrate.yaml` | A second, cheaper model writing a status line while the main call runs |

A node the workflow triggers has `run.yaml` and `events.yaml`. A node that exists to be
called by other nodes has `service.yaml` instead, and no outputs at all. Some have both.

[Anatomy of a Node](./00-manifest-nodes.md) walks through each of them with a real example.

## How you build one

1. Create the folder under a package's `nodes/`
2. Describe the node: `node.yaml`, `interface.yaml`, `config.yaml`
3. Describe the calls in `api/run.yaml`, and what comes out in `api/events.yaml`
4. Add the host to the package's `allowedHosts`
5. Check it: `unoverse node lint`
6. Run it against the real service: `unoverse node test <NodeType>`

Publish it, and once it is accepted the node is in the node library alongside every other node.

## Nodes to learn from

Every published node is public. Find the one closest to what you are building and mirror it.

**[marketplace/definitions/nodes](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes)**

| Read it for | Node |
|---|---|
| The simplest case: one call, one answer | [SearchWeb](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/search/SearchWeb) |
| Walking pages and accumulating the results | [AirtableFetch](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/airtable/AirtableFetch) |
| Writing a collection in batches the API accepts | [AirtableInsert](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/airtable/AirtableInsert) |
| A cheap existence check before an insert | [AirtableExists](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/airtable/AirtableExists) |
| Caching an answer between runs | [ApolloCompany](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/gtm/ApolloCompany) |
| Two calls, where the second uses the first | [HunterEnrich](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/gtm/HunterEnrich) |
| Starting a job and waiting for it to finish | [HyperbrowserCrawl](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/hyperbrowser/HyperbrowserCrawl) |
| Tokens streaming in as they are produced | [OpenAIStream](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/openai/OpenAIStream) |
| A request whose shape changes with the settings | [OpenAIStructuredOutput](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/openai/OpenAIStructuredOutput) |
| A node other nodes call, rather than a workflow step | [OpenAIEmbeddingService](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/openai/OpenAIEmbeddingService) |
| Offering tools to an Agent | [HubspotMCP](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/hubspot/HubspotMCP) |
| A tool loop, and a second model narrating progress | [OpenAIAgent](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/openai/OpenAIAgent) |

Whole packages worth reading: [airtable](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/airtable), [apify](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/apify),
[aws-dynamodb](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/aws-dynamodb), [aws-s3](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/aws-s3), [gtm](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/gtm),
[hubspot](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/hubspot), [hyperbrowser](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/hyperbrowser), [openai](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/openai),
[salesforce](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/salesforce), [search](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/search), [slack](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/slack) and
[x-search](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/x-search).

---

**Next**: [Anatomy of a Node](./00-manifest-nodes.md)
