---
sidebarTitle: "Beyond One Request"
title: "Beyond One Request"
---

`api/run.yaml` is an ordered list of different calls. It can say "start, then check once",
and it cannot say "check until".

These are the tools for everything that is not one plain request. Each is a key on the call
it belongs to, so they stay in the same ordered list as everything else.

| Capability | Use it when |
|---|---|
| `paginate` | the API returns results a page at a time |
| `chunk` | the API limits how many records you can send at once |
| `poll` | the work takes a while, so you start it and wait |
| `state` | the node needs to remember something between runs |
| `loop` | the node is one half of a LoopStart and LoopEnd pair |
| `presign` | you need shareable links to files, minted not fetched |
| `transport: ws` | you hold a conversation with the service rather than calling it |

The pattern is the same each time. You describe how that particular API works, and the
platform does the looping.

**None of these changes the node's `kind`, and all of them work on either.** A `PromiseNode`
can walk forty pages and still settle once. A `CallbackNode` that streams its final answer
can page through a lookup first.

What decides `kind` is the **last** call's transport, because that is the node's answer.
Every earlier call settles by definition, so an earlier step can do anything at all. See
[Node Types](./02-node-types.md).

## `paginate`: many requests, one call

Walk the pages and accumulate the results.

```yaml api/run.yaml
- name: records
  method: GET
  url: https://api.example.com/records
  transport: json
  paginate:
    strategy: cursor
    cursor: "return response.offset"
    into: offset
    items: "return response.records"
    max: "{{ config.maxRecords }}"
```

`cursor` reads the next-page token out of a reply, and a falsy result ends the walk. `into`
names the query parameter it goes back as, and the first request carries none.

For a numbered API use `strategy: page`, which also needs `size` so the platform can tell a
full page from the last one.

**The reply becomes `{ items, pages, truncated }`**, not the last page's body. The
accumulation is the answer, and handing back the final page would quietly lose the rest.

`truncated` is true when a limit stopped the walk while there was still more to fetch, so a
consumer can tell "that is everything" from "that is the first hundred".

There is a ceiling of 100 requests per call whatever `max` says, because an API that keeps
returning the same cursor would otherwise loop forever.

## `chunk`: many requests over one collection

The mirror of `paginate`. That one loops because the API decides how much comes back. This
one loops because the API limits how much you may send at once.

```yaml
- name: write
  method: POST
  url: https://api.example.com/records
  transport: json
  chunk:
    items: "return signal.input.records"
    size: 10
  body: >-
    return { records: batch }
```

Each slice is in scope as `batch`, so you describe one request and the platform repeats it.

`size` is the **API's** limit, not a preference. Airtable rejects an eleventh record,
HubSpot takes 100, Salesforce 200.

**The reply is `{ sent, batches, results, errors }`, and partial success is normal.** One
rejected batch out of ten is neither a failed call nor a successful one, and the batches
before it have already landed and cannot be taken back. A failing batch is recorded and the
walk continues, so check `errors` rather than assuming all or nothing.

There is a ceiling of 200 per batch whatever `size` says.

## `poll`: one call, a job

Start work, then ask until it is done. Every crawler, render farm, transcription and batch
import works this way.

```yaml
- name: crawl
  method: POST
  url: https://api.example.com/jobs
  transport: json
  body:
    url: "{{ config.target }}"
  poll:
    until: "return response.status === 'completed'"
    failed: "return response.status === 'failed'"
    message: "return response.error"
    url: "https://api.example.com/jobs/{{ calls.crawl.id }}/status"
    intervalMs: 2000
    maxAttempts: 90
```

**The reply is the final status payload, not the start reply.** The start reply is a receipt
carrying a job id, and handing that back would give `events` a handle where it expected the
answer.

**Always write `failed`.** Without it, a job that fails terminally is polled until it runs
out of attempts, and you get a timeout instead of the reason.

`until` is asked of the start reply first, before any polling, because some endpoints finish
inline and return the completed result with no job id at all. A manifest that assumed a
handle would fail on exactly the fast case.

`intervalMs` is capped at 60 seconds and `maxAttempts` at 300.

## `state`: remembering between runs

Sometimes an entry in the list is not a request at all.

```yaml
- name: cached
  state: read
  key: "crm:{{ scope.userId }}"

- name: contact
  when: "return !calls.cached.email"
  method: GET
  url: https://api.example.com/me
  transport: json

- name: remember
  when: "return !!calls.contact"
  state: merge
  key: "crm:{{ scope.userId }}"
  value: "return { email: calls.contact.email }"
```

Read a cache, call the API only when it was cold, write the answer back. That is one
sequence, so it stays in one list.

| Operation | Does |
|---|---|
| `read` | the value at `key`, or `{}` when nothing is stored |
| `merge` | shallow-merges `value` in, stamped with `updatedAt` |
| `drain` | pops up to `max` items off a list, oldest first |
| `save` | puts `value` into this run, for a later node to read as `saved.<nodeId>` |

`merge` is read-modify-write rather than a replace, because more than one writer shares a
key and replacing it wholesale would drop their fields.

`drain` takes items permanently, so nothing is processed twice. `max` defaults to 25 and is
bounded so one run cannot pull an unbounded queue.

Write `key` as the logical key with no prefix, usually templated from `scope`. The
deployment namespace is added by the platform, so a manifest cannot forget it and write
somewhere nothing reads.

`save` is the exception: it takes no `key`, and lint refuses one. It belongs to this run,
and a later node reads it as `saved.<nodeId>`.

## `loop`: iterating a collection across the workflow

`LoopStart` and `LoopEnd` are a pair, and `loop` is how each half keeps its place. It makes
no request.

| Operation | Does |
|---|---|
| `open` | takes `value` as the array, records it, hands back the first item as `{ item, index, total }` |
| `read` | hands back the item at the current index without moving it |
| `advance` | collects `value` for this pass, moves the index, and hands back `{ continuing, index, total, collected }` |

`key` is the id of the `LoopStart` the loop belongs to, so `LoopStart` passes
`{{ scope.nodeId }}` and `LoopEnd` passes the paired id from its own settings. The run is
supplied by the platform, so a loop can never reach another execution's state.

One capability rather than a handful of state operations, which is the point: expressing
this by hand took eight different store operations between them, and the ordering lived in
whoever wrote it.

## `presign`: shareable links, minted not fetched

Makes no request at all. It computes signed URLs from the credentials and the clock.

```yaml
- name: links
  presign:
    for: "return calls.list.objects"
    url: "return 'https://' + config.bucket + '.s3.amazonaws.com/' + item.key"
    expiresIn: 3600
    service: s3
    region: "{{ config.region }}"
```

A presigned URL moves the signature out of the header and into the query string, with an
expiry, so the link alone is enough to fetch the object. That is what makes it shareable,
and why the expiry matters: anyone holding it has that access until it lapses.

**The reply is always an array**, positionally aligned with `for`, even for one file. A
listing needs a link per object and a single file needs one, and making those different
shapes would push the difference onto every reader.

It earns its place in the ordered list for the same reason `state` does: listing a bucket
and then minting a link for each object found is one sequence.

## A socket that stays open

`transport: ws` is for a service you hold a conversation with rather than call: realtime
voice, above all. Three lists cover the whole lifecycle, and each holds messages you send.

| Key | Sent |
|---|---|
| `open` | once, in order, as soon as the socket opens |
| `send` | in reaction to something that arrived |
| `close` | once, in order, before the socket closes |

```yaml
- name: session
  transport: ws
  url: wss://api.example.com/realtime
  open:
    - message: >-
        return { type: 'session.update', session: { voice: config.voice } }
  send:
    - on: response.function_call
      message: >-
        return { type: 'tool_result', call_id: response.call_id, output: call.output }
  close:
    - message: "return { type: 'session.end' }"
```

`open` is a list because services disagree about how much of a handshake there is. One sends
a single configuration message; another needs an ordered sequence where each step is only
valid after the one before.

`close` matters more than it looks. A service that expects a teardown and never gets one is
left holding a session open, and billing for it.

`send` is deliberately general rather than tool-shaped. `toolExchange` counts turns, and a
turn is one model call, which is not an idea that exists on a socket held open for a whole
conversation. A reactive send covers a tool result going back, a response asked for, or a
keepalive, without importing the wrong model of time.

Audio is separate. `api/audio.yaml` binds a voice node to the platform's audio lane, because
binary audio cannot travel the same path as everything else. Everything that is not audio
belongs in `events.yaml` as usual.

## Declare what you use

A package declares these in `requires`, alongside auth and transport.

```yaml package.yaml
requires:
  credential: [bearer]
  transport: [json]
  paginate: [cursor]
  state: [read, merge]
  loop: [open, read, advance]
```

Publishing refuses the package where the universe cannot satisfy it. Without that, a
paginated call would fetch one page and stop, a cache would look permanently cold, and a
queue would never drain, with nothing anywhere reporting it.

## Real examples

| Capability | Node |
|---|---|
| `paginate` | [AirtableFetch](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/airtable/AirtableFetch) |
| `chunk` | [AirtableInsert](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/airtable/AirtableInsert) |
| `poll` | [HyperbrowserCrawl](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/hyperbrowser/HyperbrowserCrawl) |
| `state` | [ApolloCompany](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/gtm/ApolloCompany) |
| `presign` | [aws-s3](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/aws-s3) |

---

**Next**: [Testing](./13-testing-nodes.md)
