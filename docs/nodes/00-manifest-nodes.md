---
sidebarTitle: "Anatomy of a Node"
title: "Anatomy of a Node"
---

A node is a service you drag onto the **Canvas**. It connects an Agent to another system.

There is a marketplace of nodes. When none of them suits your situation, you build your own.

A node you build is a folder of YAML files. You describe the API call, and the platform
makes it.

You build it in **Studio**, run it against the real service, then publish it. Once it is
accepted, the node is in the node library alongside every other node.

## What belongs to you, and what belongs to the platform

> Computation over the request belongs to the platform. Description of the service belongs
> to you.

Auth schemes, retries, SSE framing, template resolution: the platform's job, written once.
Base URL, method, parameters, credentials, what comes out: yours, written as data.

You name a capability and the platform performs it. `unoverse node lint` fails on a
capability that does not exist, so you find out while you write rather than at run time.

## Build it in Studio, then publish it

You build a node in **Studio**, on your own machine. Studio reads your files straight off
disk, so there is no server to start and no database to connect to while you work. That is
why it works offline.

Publishing is a separate act pointed at a separate place. It writes your node into a
universe as a record. There is no commit, no package to build and no image to push. Where
you keep your files before that is your business.

| Step | Where |
|---|---|
| Write the node | **Studio**, on your own files |
| Check and run it | your machine, against the real service |
| Publish it | a record in the universe you chose |

### A published node waits to be accepted

A node is the only thing you publish that holds a URL and a credential, so it is the only
one somebody reviews.

Your node arrives **pending**. Whoever runs the universe sees what it is asking for before
it can run: the hosts it wants to call, the credential types it needs, and what changed
since the last version. Accepting it makes it live.

**After that, you are not interrupted.** Fix a prompt, change a mapping, correct an
expression, and publishing takes effect straight away. Publishing stops for acceptance again
only when the node reaches for something new, such as another host or another credential
type.

So the list in `allowedHosts` is not paperwork. It is the thing somebody says yes to, and it
is why they can say yes quickly.

> Publishing from **Studio** is not available yet. Today you write, check and run nodes
> locally with the two commands on this page.

## One folder is one node

```
apps/unoverse/nodes/<package>/
  package.yaml                # the package envelope: name, category, allowedHosts, requires
  credentials/
    <name>Credential.yaml     # one credential type
  shared/
    endpoints.yaml            # fragments several nodes $ref
    models.yaml
    helpers.yaml              # named functions every expression can call
  nodes/
    <NodeName>/
      node.yaml               # what it IS               (the only REQUIRED file)
      interface.yaml          # what it CONNECTS TO
      config.yaml             # the settings form
      api/                    # ALWAYS a folder
        run.yaml              #   the calls it makes
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

auth:
  required: false

capabilities:
  cacheable: false
```

`auth` is compulsory on every node, and `required: false` is the usual answer. It says your
node adds no requirement of its own, so the run reaches it as whoever the trigger admitted.
It does not mean public. [Who Can Run It](./15-who-can-run-it.md) covers the other half,
which the person building the workflow sets.

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

    # The same two fields on every node, so a workflow builder can gate this box.
    # See 15-who-can-run-it.md.
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

"ui:order": [model, prompt, authRequired, authRole]
```

`description` is the help text a person reads under the field. Say what the setting
**does**, keep it short, and don't restate the label.

`ui:field: template` is what makes a field wirable from an upstream node.

### `api/run.yaml`: the calls it makes

A list, always, even when there is one call. Each entry is named for what it fetches.

```yaml
- name: generate
  method: POST
  url: { $ref: endpoints#responses }

  credential:
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

**A call is one thing.** `transport`, `terminator` and `error` sit inside the call, because
whether a reply arrives as one body or as a stream is decided by the request you make. Ask
for `stream: true` and you get a stream.

### How the reply arrives

| `transport` | The reply is |
|---|---|
| `json` | one JSON body |
| `text` | one body of plain text |
| `xml` | one XML body, parsed to the same plain shape JSON gives |
| `headers` | the headers themselves, for an endpoint whose answer is a header |
| `binary` | bytes, handed on rather than parsed |
| `sse` | a stream of events, so the node needs `match` rows in `events.yaml` |
| `ws` | a socket that stays open in both directions |

`xml` is for the services that never moved, and it parses to the same shape as JSON so an
events row reads it identically.

`encoding` is a second axis. `transport` says how the reply is framed, `encoding` says how
the values inside it are spelled. `dynamodbJson` is the one to know: DynamoDB carries
`{ name: { S: "Ada" } }` where you want `{ name: "Ada" }`, and the platform translates both
ways so a node never writes type tags.

**It is a list because one fact often takes more than one call.** Resolving a contact is a
search by email, then a second call built from the first reply. Later calls read earlier
ones as `calls.<name>`, which is why each entry is named. A node that grows a second call
does not change shape.

A list covers different calls in order. Where one call is really many, four capabilities
cover it: `paginate` to walk pages, `chunk` to write a collection in batches, `poll` to wait
on a job, and `state` to remember between runs. See
[Beyond One Request](./12-calls-that-loop.md).

`error` matters more than it looks. An API that returns HTTP 200 with an error in the
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
the API rejected it. Only running it showed that.

## `kind` is declared, and verified

State `PromiseNode` or `CallbackNode` in `node.yaml`. It could be inferred, but it is the
first thing anyone wants to know about a node.

Lint checks the declaration instead of trusting it. A node is a **CallbackNode** when:

- its **last** call's transport streams (`sse` or `ws`), **or**
- it declares a `toolExchange`, since a tool loop is multi-turn by definition, **or**
- an input declares a `SPAWN` signal.

Only the last call is considered, because that call is the node's answer. Every earlier one
settles by definition, so a node can page through a list and then stream its reply.

Declare `PromiseNode` while doing any of them and lint names the one that contradicts you.

## Templates and expressions

Two syntaxes, and which one applies is decided by the field, never by the node.

**`{{ }}` is a Handlebars template**, resolved against the run context below.

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
implements them.

Available: member access, indexing, literals, spread, template strings, operators,
ternaries, arrow callbacks, and `JSON`, `Math`, `Number`, `String`, `Boolean`, `parseInt`,
`parseFloat`, `encodeURIComponent`, `Object.*` and `Array.*`. Plus two the platform adds,
because without them a node could not be a manifest at all:

- **`Date.now()` and `Date.iso(ms)`.** Half the APIs a node calls take a date range and want
  an ISO string. `Date.iso(Date.now() - 30 * 86400000).split('T')[0]` is thirty days ago as
  `YYYY-MM-DD`. There is no `new Date(...)`, because that is a construction the sandbox
  refuses.
- **`sha256(value)`.** A stable id derived from content, which downstream dedup joins on.

Nothing mutates. Use `.at(-1)` and never `.pop()`, `.toSorted()` and never `.sort()`. The
array you would be sorting is a live upstream output, so sorting it in place would reorder
it for every other node reading the same value.

### Give a long expression a name

An expression is one string, which is fine for `return response.data` and bad for a row
projection. When one grows past a few lines, declare it as a **helper** in any `shared/*.yaml`
file. Helpers are collected across the package and callable from every expression in it:

```yaml
# shared/helpers.yaml
helpers:
  keptMeta:
    args: [metadata, keep]
    body: >-
      return keep.filter(k => metadata[k] != null && metadata[k] !== '')
        .reduce((acc, k) => Object.assign(acc, { [k]: metadata[k] }), {})
  row:
    args: [r]
    body: "return { id: r.id, title: r.title, meta: helpers.keptMeta(r.metadata, ['tagline']) }"
```

```yaml
# api/service.yaml
returns: "return response.items.map(helpers.row)"
```

A helper sees **only its arguments and its sibling helpers**. Not `config`, not
`credentials`, not the scope of whatever called it — a named function whose answer depends on
state it never named is the thing worth avoiding, and `credentials` is in scope at most call
sites. Same sandbox, no extra authority, and a broken body fails when the package loads
rather than on the first request that reaches it.

Declare them next to the call they shape rather than in one big file. Two files declaring the
same helper name is an error, not a merge.

## The run context

What your calls can see, and where each piece comes from.

### Your node's own surroundings

| Root | Is |
|---|---|
| `config.<field>` | this node's settings, already resolved |
| `credentials.<name>.<field>` | a credential this node declared |
| `signal.<nodeId>.<output>.<field>` | an upstream node's output |
| `services.<connector>` | what is wired at run time, such as `services.mcpService.tools` |
| `prompt.<blockName>` | a prompt block from the library |

### The run it is part of

| Root | Is |
|---|---|
| `user.email`, `user.id`, `user.name` | the signed-in person |
| `scope.workflowId`, `scope.userId` | which run this is |
| `calls.<name>` | the reply from a call made earlier in this node |
| `params.<name>` | arguments a caller passed, for a service method |
| `token.instanceUrl` | where an OAuth2 exchange said to talk, when an API returns one |

**`user` is identity, and nothing that authenticates as them.** Email, id and name, never
the caller's access token. That is deliberate: a token *is* the user against our own
services, so a node holding one could send it to any host its package allows. An email
authenticates nothing.

It is a first-class root because "who is asking" is the join key for every CRM, support and
account node. Reading identity out of the request instead would let a caller fetch somebody
else's record.

```yaml
- name: contact
  method: GET
  url: https://api.example.com/contacts
  transport: json
  query:
    email: "{{ user.email }}"
```

**`calls.<name>` is how a second call uses the first.** A call skipped by its `when` leaves
no key at all, so `calls.x` is also how you ask whether it ran.

### Workflow-level values

Set on the workflow and shared by every node in it: `workflow.variables`, plus
`workflow.id`, `workflow.name`, `workflow.runId`, `workflow.userId` and
`workflow.conversationId`. Inside a loop, `loop` carries the current item, and `saved`
carries outputs other nodes chose to keep.

These resolve **before your node runs**, while its settings are being prepared. So they
belong in a `config.yaml` field, and your calls read the result as `{{ config.<field> }}`.

```yaml config.yaml
region:
  type: string
  title: Region
  default: "{{workflow.variables.region}}"
```

[Config Schema](./06-config-schema.md) covers that layer in full.

## AllowedHosts: declare every host you call

`package.yaml` lists the only hosts this package's nodes may reach. **Deny by default.**

```yaml
allowedHosts:
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
- a host missing from `allowedHosts`
- a capability the platform does not implement

## Next steps

Read [Node Discoverability](./14-node-discoverability.md) before you write `whenToUse`. It
decides whether the AI workflow builder ever offers your node.

[Config Schema](./06-config-schema.md) covers every field type your settings form can hold,
and [Credentials](./04-credentials.md) covers authenticating against a real service.
