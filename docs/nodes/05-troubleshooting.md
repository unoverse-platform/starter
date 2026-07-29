---
sidebarTitle: "Troubleshooting"
title: "Troubleshooting"
---

Two commands answer most of it.

```bash
unoverse node lint          # every static rule, before anything runs
unoverse node test <Type>   # the node against the real service
```

Lint messages name the rule they broke and the page that explains it. Start there.

## Lint stops you

| Message | What to do |
|---|---|
| `api must be a FOLDER` | Split `api.yaml` into `api/run.yaml` and `api/events.yaml` |
| `is retired: this is api/run.yaml, a LIST` | Make it a list, each entry starting `- name:` |
| `"api" is defined in api/ and node.yaml` | A section lives in one place. Delete one |
| `has no testData` | Add `test.yaml`, or a `test:` block in `node.yaml` |
| `events rows are ordered X but the connectors are Y` | Reorder the rows to match `interface.yaml` |
| `emits to "x", which is not a declared output` | The row names a connector that does not exist |
| `output "x" is declared but nothing emits to it` | Add a row, or drop the output |
| `needs credential "x" but no credentials/x.yaml exists` | Add the credential file to the package |
| `request.url is not https` | A credential must not travel in clear text |
| `capability is declared but not implemented` | Use one that exists, or ask for it to be built |
| `enumNames is a different length from enum` | They are positional |
| `ui:order names a field that does not exist` | A rename left the list behind |

## The node runs but nothing happens

**An output stays empty.** Nothing emits to it. Open `api/events.yaml` and check there is a
row whose `emit` matches the connector name.

**A streaming node emits nothing.** Its rows need `match`, naming the event type they fire
on. Without one, a row on a streaming transport fires on everything or nothing, and lint
will tell you which.

**A downstream node receives one word at a time.** The row needs `accumulate: true`, so it
emits the running total rather than each fragment.

**The node never runs at all.** A required input has nothing wired to it. The node is
waiting, which is a legitimate state, so nothing reports an error.

## A template resolved to empty

This is the one that wastes the most time, because nothing errors.

A path that matches nothing resolves to empty and says nothing about it. The usual causes:

- **The node id is wrong.** `signal.quote1.quote` needs the id **Canvas** gave that node.
  Check it against the edge you actually drew.
- **The output name is wrong.** It has to match `interface.yaml` exactly.
- **You used `input.*`.** There is no such root.
- **You used brackets.** `records[0].Name` does not resolve. Use `records.0.Name`.

Run the node and look at what it printed for the sample data. If the value is not there, the
path is wrong.

## The service rejects the request

**A number arrived as a string.** A field that is exactly one `{{ path }}` keeps its type.
Anything else, including a template with text around it, becomes a string.

**A 200 that is really a failure.** Some services answer 200 with an error in the body. Add
`error` to the call, and it will surface instead of flowing downstream as nonsense.

```yaml
error:
  when: "return !!response.error"
  message: "return response.error.message"
```

**401 from the service.** Check the credential value in **Canvas**, then check `scheme`
against the service's own documentation. Bearer and API-key-in-header are easy to confuse.

**Refused before it left.** `refusing a request to "x"` means the host is not in the
package's `allowedHosts`. Add it, and remember it is checked again after templating, so a
host built from config has to resolve to something on the list.

## An expression failed

Expressions are sandboxed. They reshape data and nothing else.

No `process`, `require`, `fetch`, `eval`, `Function`, `new`, assignment or `constructor`.
Nothing mutates either, so `.pop()` fails where `.at(-1)` works.

A rejected expression is logged and never runs.

## The Agent ignores your node

It never saw it. The AI workflow builder asks for the nodes that suit a step and gets back a
handful, so a node with weak `whenToUse` is invisible rather than rejected.

Read [Discoverability](./14-node-discoverability.md). The usual fault is an opening sentence
about mechanism rather than the job.

## The Agent ignores your tool

Same failure, one level down. A tool's `description` is what the Agent reads to decide
whether to call it. Write what the tool achieves.

If the Agent has no tools at all, nothing is wired to the `mcp` connector.

## Testing without the platform

`unoverse node test` needs no server. It reads keys from your own `.env` as
`<CREDENTIAL>_<FIELD>` in upper snake case, so `openAICredential.apiKey` is
`OPENAI_API_KEY`, and it names any that are missing before it runs.

If a node passes on the bench and fails in a workflow, the difference is what reaches it.
The bench uses `testData.inputs`; the workflow uses whatever the edges carry.

## Still stuck

- [Anatomy of a Node](./00-manifest-nodes.md) for the format
- [Config Schema](./06-config-schema.md) for templates and the run context
- [Credentials](./04-credentials.md) for keys and auth schemes
- `unoverse node lint` again, because most of this is a rule it already knows
