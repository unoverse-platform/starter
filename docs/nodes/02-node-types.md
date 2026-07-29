---
sidebarTitle: "Node Types"
title: "Node Types"
---

A node either answers once or keeps answering. Settle that first, because everything else
about the node follows from it.

| Your node | `kind` |
|---|---|
| Calls an API and gets one reply | `PromiseNode` |
| Transforms data and hands it on | `PromiseNode` |
| Reads or writes one record | `PromiseNode` |
| Streams text as it is generated | `CallbackNode` |
| Uses tools over several turns | `CallbackNode` |

You declare it at the top of `node.yaml`:

```yaml
type: Quote
kind: PromiseNode
```

## It is declared, and it is checked

`kind` could be inferred from the rest of the file. You write it anyway, because it is the
first thing anyone asks about a node.

Lint checks the declaration rather than trusting it. **A node is a `CallbackNode` when
any of these is true:**

- its **last** call's transport streams (`sse` or `ws`)
- it declares a `toolExchange`, which is a multi-turn loop by definition
- an input declares a `SPAWN` signal

Declare `PromiseNode` while doing any of them and lint names the one that contradicts you.

**Only the last call counts.** It is the node's answer, so it alone decides whether the node
streams. Every earlier call settles by definition, which is why a node can look up a record,
page through a list and then stream its reply.

**Many requests is not many emissions.** Paging, batching, waiting on a job and remembering
between runs all work on either kind and change neither. A node that walks forty pages still
settles once if its last call settles. [Beyond One Request](./12-calls-that-loop.md) covers
them.

## A node that answers once

`transport: json` says the reply arrives as one body. The events table maps that body onto
the node's outputs.

```yaml api/run.yaml
- name: fetch
  method: GET
  url: https://api.example.com/thing
  transport: json
```

```yaml api/events.yaml
- emit: text
  value: "return response.result"
```

Nothing streams, so no row needs a `match`. There is one body, and the rows shape it.

## A node that keeps answering

`transport: sse` says the reply arrives as a stream of events. Now each row names the event
type it fires on.

```yaml api/run.yaml
- name: generate
  method: POST
  url: https://api.example.com/generate
  transport: sse
  terminator: "[DONE]"
  body:
    stream: true
```

```yaml api/events.yaml
- emit: stream
  match: response.output_text.delta
  value: "return response.delta"
  accumulate: true
  throttleMs: 200

- emit: text
  from: complete
  value: "return events.filter(e => e.emit === 'stream').map(e => e.value).at(-1) ?? ''"
```

Two things there are worth copying into any streaming node.

**`accumulate: true` emits the running total, not the fragment.** A stream of single words is
almost never what a downstream node wants. It wants the answer so far.

**`throttleMs` bounds how often it emits.** A long answer would otherwise produce hundreds of
events. Nothing held back is lost, because whatever is pending is flushed when the run ends.

The last row uses `from: complete`, which fires once at the end over everything emitted. That
is how a streaming node also produces a settled final value.

## Where each part lives

| Question | File |
|---|---|
| Does it answer once or many times? | `node.yaml`, as `kind` |
| How does the reply arrive? | `api/run.yaml`, as `transport` |
| What leaves the node, and when? | `api/events.yaml` |
| What has to arrive before it runs? | `interface.yaml`, as `required` |

[Anatomy of a Node](./00-manifest-nodes.md) walks through all of them.
