---
sidebarTitle: "Config Schema"
title: "Config Schema"
---

`config.yaml` is the settings form. **Canvas** renders it, someone fills it in, and your
calls read the saved values as `{{ config.<field> }}`.

It is the file you touch most. Every new option a node grows lands here and nowhere else.

```yaml config.yaml
$schema: ../../../_schema/config.schema.json

configSchema:
  type: object
  required: [model]
  properties:
    model:
      type: string
      title: Model
      description: Which model answers
      enum: [fast, balanced, deep]
      enumNames: [Fast, Balanced, Deep reasoning]
      default: balanced

    prompt:
      type: string
      title: Prompt
      description: The request to answer. Usually wired in from an upstream node.
      default: ""
      ui:field: template

"ui:order": [model, prompt]
```

`configSchema` is a JSON Schema, so any keyword you already know works. The `ui:` keys are
the platform's, and they decide how a field is drawn.

## Writing the labels

Three fields decide whether the form makes sense to the person filling it in.

| Key | Is |
|---|---|
| `title` | The label. Without one the raw property name is shown, which reads as unfinished |
| `description` | The help text under the field |
| `default` | What the field starts as |

**Say what the setting does, not what it is called.** "Maximum number of tokens to generate"
tells a reader nothing they could not get from the label. "The model stops when it hits this,
mid-sentence and without an error" tells them why they might change it.

Keep it to a line or two. Detail belongs in your node's own documentation, not under a form
field.

## Field types

### Text

```yaml
systemPrompt:
  type: string
  title: System Prompt
  description: Standing instructions for every run. Optional.
  default: ""
  ui:field: template
```

### A choice

`enum` is the values, `enumNames` is what a person sees. They are positional, so they must be
the same length.

```yaml
tone:
  type: string
  title: Tone
  enum: [neutral, warm, terse]
  enumNames: [Neutral, Warm, Terse]
  default: neutral
```

### A number

```yaml
maxTokens:
  type: number
  title: Max Tokens
  description: The reply stops when it hits this, mid-sentence and without an error.
  default: 1200
  minimum: 1
  maximum: 128000
  step: 100
```

`minimum` and `maximum` are enforced, so a bad value is caught in the form rather than by the
service.

### A switch

```yaml
includeSources:
  type: boolean
  title: Include sources
  default: false
  ui:widget: toggle
```

### Structured data

```yaml
schema:
  type: object
  title: Output schema
  description: The JSON Schema the answer must match.
  ui:field: template
```

## Making a field wirable

`ui:field: template` is what lets a field take data from an upstream node instead of a typed
value. Without it, the field is whatever someone typed.

**The syntax is decided by the field's `type`, always, on every node.**

**A `string` field takes a Handlebars template.**

```yaml
prompt: "Summarise this: {{signal.inputtrigger1.output.message}}"
```

Five roots are available:

| Root | Reaches |
|---|---|
| `signal.<nodeId>.<output>.<field>` | an upstream node's output |
| `config.<field>` | another of this node's settings |
| `credentials.<name>.<field>` | this node's credential |
| `services.<connector>` | what is wired at run time |
| `prompt.<blockName>` | a prompt block from the library |

There is **no `input.*` root**. A path that matches nothing resolves to empty and says
nothing about it, so check the id against the edge you actually drew. Array elements and
object keys are dot segments, never brackets: `records.0.Name`, not `records[0].Name`.

Helpers work anywhere a template does: `eq`, `contains`, `filter` and `toJSON`. So a
conditional lives in the field itself.

```yaml
systemPrompt: |-
  {{#if (eq config.tone "warm")}}Be warm.{{else}}Be terse.{{/if}}
  {{prompt.markdownGuidelines}}
```

**An `object` or `array` field takes a `return` expression instead.**

```yaml
payload: "return { topic: signal.inputtrigger1.output.message, images: signal.upload1.files }"
```

A nested object of templates, like `{ topic: "{{...}}" }`, is not valid and never resolves.

## The running workflow

The five roots above are your node's own surroundings. A config field can also reach the
**run** it is part of.

| Root | Reaches |
|---|---|
| `workflow.id` | the workflow being run |
| `workflow.name` | its name |
| `workflow.runId` | this particular run |
| `workflow.userId` | the person the run belongs to |
| `workflow.conversationId` | the conversation it is part of |
| `workflow.variables` | variables set on the workflow, shared by every node in it |
| `loop` | the current item, inside a loop |
| `saved` | outputs other nodes chose to save, keyed by node id |

```yaml
prompt: "Answer for {{workflow.variables.customerName}} in {{workflow.variables.locale}}."
```

`workflow.variables` is the one to reach for when several nodes need the same value. Set it
once on the workflow rather than wiring it into each node.

These are resolved **before your node runs**, when the platform prepares its settings. So
they are available in `config.yaml` fields, and your calls read the result as
`{{ config.<field> }}`.

## What a `return` expression may do

It is not JavaScript. It is a data-shaping expression that reshapes what is already in front
of it, and nothing else.

**Allowed:** reading the context, indexing, object and array literals, spread, template
strings, operators, ternaries, and arrow callbacks like `items.map(x => x.name)`.

| Available | For |
|---|---|
| `JSON`, `Math`, `Number`, `String`, `Boolean` | the ordinary ones |
| `parseInt`, `parseFloat`, `isNaN`, `isFinite` | parsing |
| `encodeURIComponent`, `encodeURI` | building a URL from data, so an id with a space or a slash encodes rather than breaking |
| `Date.now()`, `Date.iso(ms)` | timestamps and ISO strings |
| `sha256(value)` | a stable id derived from content |
| `Object.keys/values/entries/fromEntries/assign` | reshaping |
| `Array.isArray/from/of` | building arrays |

Methods: the non-mutating array ones (`map`, `filter`, `slice`, `find`, `reduce`, `flat`,
`at`, `toSorted`), the string ones (`split`, `replace`, `trim`, `padStart`, `match`), and
`toFixed`.

**Rejected:** `process`, `require`, `fetch`, `globalThis`, `eval`, `Function`, `new`,
assignment, statement blocks, `constructor` and `__proto__`. A rejected expression is logged
and never runs.

**Nothing mutates.** Use `.at(-1)` rather than `.pop()`, and `.toSorted()` rather than
`.sort()`. `sort` reorders the array in place, and that array is a live upstream output, so
sorting it would reorder it for every other node reading the same value.

### Dates

Half the APIs a node calls take a date range, and every one of them wants `YYYY-MM-DD` or a
full ISO string. `Date.iso` is the formatter.

```yaml
since: "return Date.iso(Date.now() - 30 * 86400000).split('T')[0]"
```

`Date.now()` is milliseconds, `Date.iso(ms)` gives the full ISO string, and `.split('T')[0]`
gives the date part. One function rather than a family, and there is no `new Date(...)`
because that is a construction the sandbox refuses.

Security here is by absence. The interpreter never implements those globals, so there is
nothing for an expression to escape to.

## Showing a field only when it matters

`ui:dependencies` hides a field until another field has the right value. A scalar means it
must match exactly, an array means it must be one of several, and multiple keys are all
required at once.

```yaml
mode:
  type: string
  title: Mode
  enum: [simple, advanced]
  default: simple

retries:
  type: number
  title: Retries
  default: 3
  ui:dependencies:
    mode: advanced

timeout:
  type: number
  title: Timeout
  ui:dependencies:
    mode: [advanced, expert]
```

Lint checks that every key names a real sibling field, so a rename cannot leave a field
permanently hidden.

## The two fields every node has

Two of them are not yours to choose. They are identical in every node, and lint checks they
are there:

```yaml
authRequired:
  type: boolean
  title: Require sign-in
  description: >-
    Only a signed-in caller may run this step. Leave off and it runs for whoever the
    workflow's trigger admitted, which is the usual answer.
  default: false
  "ui:widget": toggle

authRole:
  type: string
  title: Require role
  description: >-
    A claim the caller's account must carry, as noun:verb (finance:approve,
    payments:refund). Leave blank to require only that they are signed in.
  default: ""
  "ui:dependencies": { authRequired: true }
```

These belong to the person building the workflow, not to you. The same node type faces staff
on one canvas and customers on another, and only they know which. Your own floor goes in
`node.yaml`, and the stricter of the two wins.

Both default to off, because a node that gated by default would break every workflow already
using it. [Who Can Run It](./15-who-can-run-it.md) covers the whole model.

## The rest of the vocabulary

| Key | Does |
|---|---|
| `ui:order` | The order fields appear in. Lint warns about any field you leave out |
| `ui:widget: toggle` | A switch instead of a checkbox |
| `ui:widget: select` | A dropdown where the default control would not be one |
| `ui:field: textarea` | A multi-line box |
| `ui:field: password` | Masks what is typed |
| `ui:field: code` | A code editor |
| `ui:hidden` | Keeps the field in the schema and out of the form |
| `required` | Named at the `configSchema` level, not on the field |

## When it goes wrong

| What you see | Why |
|---|---|
| A field labelled with its property name | No `title` |
| The template arrived empty and nothing errored | The path matched nothing. Check the node id against the edge you drew |
| The service rejected a number as a string | The value went through a template. A field that is exactly one `{{ path }}` keeps its type; anything else becomes text |
| Lint: `ui:order` names a field that does not exist | A rename left the list behind |
| Lint: `enumNames` is a different length from `enum` | They are positional |
| A field never appears | A `ui:dependencies` condition that can never be true |

---

**Next**: [Service Connectors](./07-service-connectors.md)
