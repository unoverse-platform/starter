---
sidebarTitle: "3. Create Your First Node"
title: "Create Your First Node"
---

When the node library doesn't have what you need, you write it. A node is a folder of YAML: you describe the service you want to call, and the platform performs it.

There is nothing to compile and no package to install. You write the files, run the node against the real API, then publish it.

| | |
| --- | --- |
| **What you'll build** | <span className="node-chip">Quote</span>, a node that fetches a famous quote |
| **Where it lives** | `apps/unoverse/nodes/quote/` |
| **What it outputs** | Two connectors: `quote` and `author` |
| **Why this API** | It needs no key, so you can build and run it in under a minute |

## Before you begin

The platform is running (`unoverse dev`). You've built the workflow from [Create Your First Agent](./02-create-your-first-agent.md); you'll extend it to test your node.

Here is the node you are about to build, as **Canvas** will draw it:

<div style={{ position: "relative", width: "240px", margin: "1.75rem 0", borderRadius: "12px", border: "1px solid rgb(229 231 235)", background: "#fff", boxShadow: "0 4px 6px -1px rgb(0 0 0 / 0.1)", fontFamily: "inherit" }}>
  <div style={{ padding: "13px 16px", borderRadius: "12px 12px 0 0", background: "#7c5cff", lineHeight: 1.25 }}>
    <div style={{ margin: 0, color: "#fff", fontWeight: 600, fontSize: "16px" }}>My custom node</div>
    <div style={{ margin: 0, color: "rgb(255 255 255 / 0.7)", fontSize: "12px" }}>Quote</div>
  </div>
  <div style={{ display: "flex", alignItems: "center", gap: "10px", padding: "16px", color: "rgb(75 85 99)", fontSize: "14px", lineHeight: 1 }}>
    <span style={{ width: "12px", height: "12px", borderRadius: "9999px", background: "rgb(156 163 175)" }} />
    Ready
  </div>
  <span style={{ position: "absolute", top: "50%", left: "-8.5px", width: "17px", height: "17px", marginTop: "-8.5px", borderRadius: "9999px", border: "3px solid #fff", background: "#7c5cff", boxShadow: "0 2px 6px rgb(0 0 0 / 0.2)", zIndex: -1 }} />
  <span style={{ position: "absolute", top: "20%", right: "-8.5px", width: "17px", height: "17px", marginTop: "-8.5px", borderRadius: "9999px", border: "3px solid #fff", background: "#7c5cff", boxShadow: "0 2px 6px rgb(0 0 0 / 0.2)", zIndex: -1 }} />
  <span style={{ position: "absolute", top: "80%", right: "-8.5px", width: "17px", height: "17px", marginTop: "-8.5px", borderRadius: "9999px", border: "3px solid #fff", background: "#7c5cff", boxShadow: "0 2px 6px rgb(0 0 0 / 0.2)", zIndex: -1 }} />
</div>

The bold line is this node's name on your canvas, and you can rename it to whatever the step is doing. The line beneath it is the node type, `Quote`, which never changes.

The colour and the type come from the files below. So do the handles: one on the left for the input, one on the right per output. Hover a handle and its connector name appears.

## Build it

Four small files, and none of them is code.

<div className="security-callout">
  <div className="security-eyebrow">What a node cannot do</div>
  <ul>
    <li><strong>It adds no code.</strong> The platform runs its own executor, the same one for every node.</li>
    <li><strong>It reaches only declared hosts.</strong> Anything else is refused, and https only.</li>
    <li><strong>It carries no keys.</strong> Yours stay in <strong>Canvas</strong>, supplied as it runs.</li>
    <li><strong>It is sealed.</strong> A stored copy that changed is refused at load.</li>
  </ul>
</div>

[Anatomy of a Node](../nodes/00-manifest-nodes.md) covers each of those in full.

<Steps>
<Step title="Create the package">

A package holds one or more nodes and declares which hosts they may call. Create `apps/unoverse/nodes/quote/` with one file in it:

```yaml package.yaml
$schema: ../_schema/package.schema.json

name: quote
displayName: Quote
description: A famous quote, fetched fresh each run
version: 1.0.0
category: search

allowedHosts:
  - zenquotes.io
```

`allowedHosts` is the list of hosts this package may reach, and everything else is refused. A node cannot call anywhere you have not named here.

</Step>
<Step title="Describe the node">

Create `quote/nodes/Quote/node.yaml`. This one file says what the node is, what it connects to, and how to test it.

```yaml nodes/Quote/node.yaml
$schema: ../../../_schema/node.schema.json

type: Quote
kind: PromiseNode

name: Quote
category: Search
color: "#7c5cff"
description: Fetches a random famous quote and its author

whenToUse: Pick when a step needs a famous quote. No settings to fill in.

# Who may run it. Compulsory on every node, and `required: false` is the usual answer:
# the node adds no requirement of its own and runs for whoever the trigger admitted.
auth:
  required: false

capabilities:
  cacheable: false

interface:
  inputs:
    - name: signal
      type: object
      description: Data from previous nodes
  outputs:
    - name: quote
      type: string
      description: The quote text
    - name: author
      type: string
      description: Who said it

# This node has no settings of its own, but every node carries these two. They are the
# WORKFLOW BUILDER's control over who may run this particular box on their canvas, which is
# a different question from the `auth` block above (yours, and true of every copy).
config:
  configSchema:
    type: object
    properties:
      authRequired:
        type: boolean
        title: Require sign-in
        default: false
        "ui:widget": toggle
      authRole:
        type: string
        title: Require role
        default: ""
        "ui:dependencies": { authRequired: true }
  "ui:order": [authRequired, authRole]

test:
  testData:
    config: {}
    inputs:
      signal: {}
    expect:
      quote: "return output.quote.length > 0"
      author: "return output.author.length > 0"
```

Each entry in `outputs` becomes a connector on the node. Downstream nodes read them as `signal.quote1.quote` and `signal.quote1.author`, where `quote1` is the id **Canvas** gives the node when you drag it in.

A bigger node splits `interface` and `test` into their own files. This one is small, so they stay here.

<Note>
`whenToUse` decides whether the AI workflow builder can find your node at all. The catalog ranks it against the task being built, so lead with the outcome in plain words and keep it to one or two sentences. Describe what disqualifies your node as a property ("no settings to fill in"), and never name another node. The full guide is [Node Discoverability](../nodes/14-node-discoverability.md); read it before writing this field for a real node.
</Note>

</Step>
<Step title="Describe the call">

Create `quote/nodes/Quote/api/run.yaml`. It lists the calls the node makes, and this node makes one.

```yaml nodes/Quote/api/run.yaml
- name: fetch
  method: GET
  url: https://zenquotes.io/api/random
  transport: json
```

It is a list even with one call, because a node often needs two: fetch a record, then fetch something the first reply pointed at. Naming each one is how a later call reads an earlier reply.

`transport: json` says the reply arrives as one body. A streaming service uses `transport: sse` instead, and the node emits as tokens arrive.

</Step>
<Step title="Describe what comes out">

Create `quote/nodes/Quote/api/events.yaml`. One row per output connector, in the order the node declares them.

```yaml nodes/Quote/api/events.yaml
- emit: quote
  from: response
  value: "return response[0].q"

- emit: author
  from: response
  value: "return response[0].a"
```

This API returns an array with one object in it, so `response[0].q` is the quote text. Read this file and you know everything the node emits, without opening another one.

</Step>
<Step title="Check it">

```bash Check the node
unoverse node lint
```

Every message names the rule it broke and the page that explains it. Leave out the fixture above and it tells you so, rather than letting you find out later in a workflow.

</Step>
<Step title="Run it against the real API">

```bash Run the node
unoverse node test Quote
```

```
Quote  (quote/Quote, PromiseNode)
GET https://zenquotes.io/api/random   transport: json

── outputs ──
  quote        Less is more.
  author       Robert Browning
── expect ──
  ✓ quote  return output.quote.length > 0
  ✓ author  return output.author.length > 0

✓ Quote ran in 893ms
```

The platform doesn't need to be running for this. It is your node, your machine, the real API.

</Step>
<Step title="Use it in a workflow">

Deploy the node, and <span className="node-chip">Quote</span> is in the node library in **Canvas**.

Open your workflow from [Create Your First Agent](./02-create-your-first-agent.md), drag <span className="node-chip">Quote</span> in, and connect <span className="node-chip">Input Trigger</span> to it.

Step through the workflow. Quote's **Debug** tab shows a fresh quote from the API.

Now feed it to the model: reference `signal.quote1.quote` in the <span className="node-chip">OpenAI Stream</span> prompt, and your Agent opens its answer with a famous quote.

</Step>
</Steps>

## When a node needs a key

Quote needs no key. Most services do, and the key never goes in these files.

A node declares what it needs, by name:

```yaml nodes/YourNode/node.yaml
interface:
  credentials:
    - name: yourServiceCredential
      required: true
      displayName: Your Service
```

Then the request uses it:

```yaml nodes/YourNode/api/run.yaml
- name: fetch
  credential:
    scheme: bearer
    token: "{{ credentials.yourServiceCredential.apiKey }}"
```

You enter the key once in **Canvas**, under Credentials. The platform encrypts it, and supplies it to the node at the moment it runs. The value is never in your files, never in git, and never in the node you hand to someone else.

A node carries no keys, so sharing one never shares a secret. [Credentials](../nodes/04-credentials.md) covers the full pattern.

## Sharing it

Your node runs from the files in your repo, which is all you need while you build.

To give it to anyone else, you publish it from **Studio**. Publishing writes the node into a universe as a record: no build, no package, nothing to download.

A node arrives pending, because it is the only thing you publish that holds a URL and a key. Whoever runs the universe sees the hosts it wants to call and the credentials it needs, and accepting it makes it live. After that you publish freely, and it only pauses again if the node reaches for something new.

<Note>
Publishing from **Studio** is not available yet. Until it is, a node lives in the repo it was written in.
</Note>

## Have Claude Code build it

<div className="skill-callout">
<img className="skill-logo" src="/images/onboarding/claude-logo.png" alt="Claude" />
<div className="skill-eyebrow">Claude Code skill · ships with your repo</div>
<div className="skill-title">/unoverse-create</div>

Claude Code already knows everything on this page. Open your repo in Claude Code and describe the node you want:

> Create a node that fetches the top story from a news API.

The skill writes the files, adds the host to `allowedHosts`, checks it, and runs it against the real API.

Not sure everything is wired up? Type `/mcp` in Claude Code: the `unoverse-builder` server should show as connected.

</div>

Using a different AI assistant? Point it at the node reference in your repo at `docs/nodes/`. It is the same material as the [Nodes](../nodes/overview.md) tab of these docs.

## Next steps

<Card title="Ingest content to Spatial" icon="globe" href="./04-ingest-content-to-spatial.md" horizontal>
Ground your Agent's answers in your own content.
</Card>

<Card title="Components and templates" icon="palette" href="./05-components-and-templates.md" horizontal>
Design the interfaces your Agents speak through.
</Card>
