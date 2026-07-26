---
sidebarTitle: "Anatomy of a Node"
title: "Anatomy of a Node"
---

A node is a folder of YAML. You describe the service you want to call, and the platform
performs it.

There is nothing to compile and nothing to publish. Save a file and your node is in the node
library in **Canvas**.

Two things follow from a node being data. You can read one and know exactly what it does.
And the platform can run someone else's node without running their code.

## What belongs to you, and what belongs to the platform

> Computation over the request belongs to the platform. Description of the service belongs
> to you.

Auth schemes, retries, SSE framing, template resolution: the platform's job, written once.
Base URL, method, parameters, credentials, what comes out: yours, written as data.

You name a capability and the platform performs it. `unoverse node lint` fails on a
capability that does not exist, so you find out while you write rather than at run time.

## Where you work

You build in **Studio**, against the files in your own repo. There is no server to start and
no database to connect to.

Your repo is the source of truth for what a node is. An environment holds a copy, and the
flow only goes one way.

| Where | Reads from |
|---|---|
| **Studio**, local | the YAML files in your repo |
| **Studio**, connected to an environment | that environment's records |
| A running environment | its own records |

A node is data, so shipping one is writing a record. Never edit a record by hand. A change
with no commit behind it cannot be reviewed or rolled back.

> Publishing from **Studio** is not available yet. Today you author, check and run nodes
> locally with the two commands on this page.

## One folder is one node

```
apps/unoverse/nodes/<package>/
  package.yaml                # the package envelope: name, category, egress, requires
  credentials/
    <name>Credential.yaml     # one credential type
  shared/
    endpoints.yaml            # fragments several nodes $ref
    models.yaml
  nodes/
    <NodeName>/
      node.yaml               # what it IS               (the only REQUIRED file)
      interface.yaml          # what it CONNECTS TO
      config.yaml             # the settings form
      api/                    # ALWAYS a folder
        request.yaml          #   the call
        events.yaml           #   everything that leaves the node
      test.yaml               # a fixture you can actually run
```

Each file carries a `$schema` pointer, so your editor autocompletes every field and shows
errors as you type. The schema descriptions are the field reference, so they cannot drift
from the format.

### The split is by rate of change

| File | Holds | How often you touch it |
|---|---|---|
| `node.yaml` | type, kind, name, category, description, whenToUse | Once |
| `interface.yaml` | inputs, outputs, credentials, serviceConnectors | When the node's shape changes |
| `config.yaml` | `configSchema` + `ui:order` | Constantly. Every new option lands here |
| `api/` | one file per call, plus the events table | When the upstream API changes |
| `test.yaml` | `testData` | Alongside config |

`interface.yaml` is its own file for a different reason than the rest: it answers the
question asked most about any node, "what can I connect to this?", and that should never
mean scrolling past a logo URL.

Every section except `api` may instead be inlined into `node.yaml`, so a simple node can
be one file. Defining a section in two places is an error, never a merge.

## The five files

Taken from the real `OpenAI` node, trimmed of its comments.

### `node.yaml`: what it is

```yaml
$schema: ../../../_schema/node.schema.json

type: OpenAI
kind: PromiseNode

name: OpenAI
category: AI
description: One prompt in, one completion out, with no streaming or tools

whenToUse: >-
  Single prompt to single completion, the plain one-shot text generator: summarise,
  rewrite, classify, answer. No streaming, no tools, no schema enforcement.

capabilities:
  cacheable: false
```

`whenToUse` is not documentation. The catalog embeds it and ranks it against what a
workflow-building agent is trying to do, so it decides whether your node is ever
**offered**. Read [14-node-discoverability.md](./14-node-discoverability.md) before you
write it.

### `interface.yaml`: what it connects to

```yaml
$schema: ../../../_schema/interface.schema.json

inputs:
  - name: signal
    type: object
    description: Data from previous nodes that can be referenced in templates

outputs:
  - name: text
    type: string
    description: The generated text
  - name: usage
    type: object
    description: Token usage for this call

credentials:
  - name: openAICredential
    required: true
    displayName: OpenAI API
```

### `config.yaml`: the settings form

Canvas renders the form from this, and the executor resolves `{{ config.* }}` against the
saved values.

```yaml
$schema: ../../../_schema/config.schema.json

configSchema:
  type: object
  required: [model]
  properties:
    model:
      type: string
      title: Model
      enum: { $ref: models#enum }
      enumNames: { $ref: models#enumNames }
      default: { $ref: models#default }
    prompt:
      type: string
      title: Prompt
      description: The request to answer. Usually wired in from an upstream node.
      default: ""
      ui:field: template

"ui:order": [model, prompt]
```

`description` is the help text a person reads under the field. Say what the setting
**does**, keep it short, and don't restate the label.

`ui:field: template` is what makes a field wirable from an upstream node.

### `api/request.yaml`: the call

```yaml
method: POST
url: { $ref: endpoints#responses }

auth:
  scheme: bearer
  token: "{{ credentials.openAICredential.apiKey }}"

body:
  model: "{{ config.model }}"
  input: "{{ config.prompt }}"
  max_output_tokens: "{{ config.maxTokens }}"

timeoutMs: 120000

retry:
  attempts: 3
  backoff: exponential
  on: [429, 500, 502, 503, 504]

transport: json

error:
  when: "return !!response.error"
  message: "return response.error.message"
```

**A call is one thing.** `transport`, `terminator` and `error` live here, not in a file of
their own, because whether a reply arrives as one JSON body or as a stream is decided by
the request you make. Ask for `stream: true` and you get a stream.

`error` matters more than it looks. A vendor that returns HTTP 200 with an error in the
body will otherwise read as success and hand nonsense downstream.

### `api/events.yaml`: everything that leaves the node

**One row per output connector, in the same order `interface.yaml` declares them.** Read
this one file and you know the node's entire outward behaviour. Lint enforces the coverage
and the order, so it stays true after edits.

```yaml
- emit: text
  from: response
  value: "return response.output.filter(o => o.type === 'message').map(...).join('')"

- emit: usage
  from: response
  value: "return response.usage"
```

A row's `from` says where it fires:

| `from` | Fires | What's in scope |
|---|---|---|
| `response` | a streamed event matching `match`, or the whole body when the transport settles | `response` |
| `narrator` | each line the narrator writes | `narrator.line` |
| `tool` | after a tool call RETURNS, with its result | `call.name`, `call.args`, `call.output` |
| `complete` | once at the end, over everything emitted | `events` |

`from: tool` exists because a tool's result is never in the HTTP stream. The tool loop
produced it.

For a streaming node, two controls matter:

- `accumulate: true` emits the running total instead of the fragment. A consumer wants the
  text so far, not one word.
- `throttleMs` or `throttleChars` bound how often a row emits. Nothing held back is
  dropped; it is flushed when the run ends.

```yaml
- emit: stream
  from: response
  match: response.output_text.delta
  value: "return response.delta"
  accumulate: true
  throttleMs: 200
```

### `test.yaml`: a fixture that runs

```yaml
$schema: ../../../_schema/test.schema.json

testData:
  config:
    model: gpt-5.6
    prompt: Explain what a workflow engine does, in two sentences.
    maxTokens: 1200
  inputs:
    signal: { topic: workflow engines }
  expect:
    text: "return output.text.length > 0"
    usage: "return output.usage.total_tokens > 0"
```

Then run it against the real API, with no platform running:

```bash
unoverse node test OpenAI
```

Keys come from your own `.env` as `<CREDENTIAL>_<FIELD>` in upper snake case, so
`openAICredential.apiKey` reads `OPENAICREDENTIAL_APIKEY`. They are read for that one run
and stored nowhere. This is deliberate: you test with **your** key, never with a universe's
stored credentials, which your manifest has no way to reach.

This catches the class of mistake no static check can. A real example: Handlebars always
produces a string, so `max_output_tokens: "{{ config.maxTokens }}"` once sent `"2048"` and
the vendor rejected it. Only running it showed that.

## `kind` is declared, and verified

State `PromiseNode` or `CallbackNode` in `node.yaml`. It could be inferred, but it is the
first thing anyone wants to know about a node.

Lint checks the declaration instead of trusting it. A node is a **CallbackNode** when:

- the request's transport streams (`sse`, `ndjson`, `awsEventStream`), **or**
- any input declares signal `CONTINUE` or `SPAWN`, **or**
- it declares a `toolExchange`, since a tool loop is multi-turn by definition.

Transport alone is not enough, and that is the case worth catching: a node iterating a
collection settles its HTTP call once yet still needs callback machinery. Its CONTINUE port
is the tell.

## Templates and expressions

Two syntaxes, and which one applies is decided by the field, never by the node.

**`{{ }}` is a Handlebars template.** Five roots:

| Root | Is |
|---|---|
| `signal.<sourceId>.<outputHandle>.<field>` | an upstream node's output |
| `config.<field>` | this node's own settings |
| `credentials.<name>.<field>` | this node's resolved credential |
| `services.<connector>` | what is WIRED at run time, e.g. `services.mcpService.tools` |
| `prompt.<blockName>` | a prompt block from the library |

Registered helpers work anywhere a template does: `eq`, `contains`, `filter`, `toJSON`.
So conditional prompt text is an ordinary `{{#if}}`, including inside a System Prompt a
user typed:

```yaml
instructions: |-
  {{#if (eq config.tone "warm")}}Be warm.{{else}}Be terse.{{/if}}
  {{prompt.markdownGuidelines}}
```

There is **no `{{input.*}}` root.** A wrong path resolves to empty silently. Array
elements and object keys are dot segments, never brackets: `records.0.Name`.

`prompt.<blockName>` is why a manifest should never hard-code instruction text. Blocks live
in `prompts/blocks/**/*.md`, are toggleable, and are camelCased from the filename
(`markdown-guidelines.md` becomes `{{prompt.markdownGuidelines}}`). A copy of a block's
words baked into a node is a fork that silently stops tracking the block.

**A string starting with `return ` is a sandboxed expression**, evaluated at any depth. Use
it when a value's SHAPE depends on the run: an array member that is only sometimes present,
or a key whose name varies by model. It is the same evaluator config template fields
already use, so it is not a second language to learn.

Security is by absence. There is no `process`, `require`, `fetch`, `eval`, `new`,
assignment or `constructor` for an expression to reach, because the interpreter never
implements them. Allowed: member access, indexing, literals, spread, template strings,
operators, ternaries, and safe array/string/`JSON`/`Math` methods including `.map(x => …)`.
Nothing mutates, so use `.at(-1)` and never `.pop()`.

## Egress: declare every host you call

`package.yaml` lists the only hosts this package's nodes may reach. **Deny by default.**

```yaml
egress:
  - api.openai.com
```

The host list is what makes a manifest safe to accept from someone else. "Data cannot
execute" does not save you on its own: a URL plus `{{ credentials.x.apiKey }}` is
exfiltration in six lines with nothing to sandbox. So the capability is restricted instead.

Enforced twice: statically by lint, and at run time **after** templating, because a host
can itself be templated. Non-https is refused outright, since a credential must never
travel in clear text. `*.example.com` matches exactly one subdomain level.

## Check it before you run it

```bash
unoverse node lint
```

Every message names the rule it broke and the page that explains it. Errors stop the build.
Warnings inform.

It catches what would otherwise surface much later, in a workflow, as nothing happening:

- an output connector nothing emits to
- an events table out of connector order
- a credential field that does not exist
- a `testData.config` key your `config.yaml` never declared
- a host missing from `egress`
- a capability the platform does not implement

## Next steps

Read [Node Discoverability](./14-node-discoverability.md) before you write `whenToUse`. It
decides whether the AI workflow builder ever offers your node.

[Config Schema](./06-config-schema.md) covers every field type your settings form can hold,
and [Credentials](./04-credentials.md) covers authenticating against a real service.
