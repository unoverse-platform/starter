---
sidebarTitle: "Testing Nodes"
title: "Testing Nodes"
---

Run your node against the real service before you put it in a workflow. **Studio** has a
Nodes tab for exactly that, and nothing has to be published first.

## In Studio

Open the **Nodes** tab and pick your node. You get three panes.

**The node**, as everyone else will read it: name, category, description, and the
`whenToUse` you wrote. Any credential it needs is named here too, so a node asking for
something you have not set up says so before you run it.

**The settings**, rendered from your `config.yaml`. This is the same form **Canvas** shows,
built from the same file, so a field that reads badly here reads badly everywhere.

**The output**, empty until you press Run.

Fill in the settings, press **Run**, and the node calls the real service. A streaming node
streams into the pane as it arrives.

This is the fastest way to see whether your node works, and it is also the honest preview of
your `config.yaml`. If the labels are unclear or the fields are in a strange order, fix it
now rather than after someone else meets it.

## Load sample

If your node has `test.yaml`, Studio shows a **Load sample** button. It fills the form from
`testData.config` and the inputs from `testData.inputs`, so you are one click from a run
rather than typing settings each time.

That is most of why `test.yaml` earns its place.

```yaml test.yaml
$schema: ../../../_schema/test.schema.json

testData:
  config:
    model: gpt-5.6
    prompt: Explain what a workflow engine does, in two sentences.
    maxTokens: 1200
  inputs:
    signal:
      topic: workflow engines
  expect:
    text: "return output.text.length > 0"
```

Write the fixture as a real request, not a minimal one. It is the sample every future
reader loads first.

## From the command line

The same run, without opening anything:

```bash
unoverse node test <NodeType>
```

It prints the call it is about to make, the sample data it is using, what each output
received, and whether the `expect` assertions passed.

```
OpenAI  (openai/OpenAI, PromiseNode)
POST https://api.openai.com/v1/responses   transport: json

── sample data (test.yaml) ──
  model              gpt-5.6
  prompt             Explain what a workflow engine does, in two sentences.

── outputs ──
  text         A workflow engine automates, coordinates and monitors…
  usage        {"input_tokens":29,…}
── expect ──
  ✓ text  return output.text.length > 0

✓ OpenAI ran in 1302ms
```

The platform does not need to be running. It is your node, your machine, the real service.

## Keys stay yours

Both routes need a real key, and neither stores one.

The command line reads your own `.env`, using the credential name and field in upper snake
case with any trailing `Credential` dropped. So `openAICredential.apiKey` is
`OPENAI_API_KEY`. A missing one is named before anything runs.

## What `expect` is for

`expect` turns a run into a check. Each key is an output, and each value is an expression
over `output` that has to come back true.

```yaml
expect:
  text: "return output.text.length > 0"
  usage: "return output.usage.total_tokens > 0"
```

Assert the **shape**, not the words. A model writes something different every time, so
`output.text.length > 0` holds and `output.text === "Hello"` does not.

For a service node, name the method to call:

```yaml
testData:
  call:
    method: createEmbedding
    params: { text: hello }
  expect:
    embedding: "return output.dimensions === 1024"
```

## What a run cannot tell you

A node can pass here and still misbehave in a workflow, because the bench feeds it
`testData.inputs` while a workflow feeds it whatever the edges carry.

When that happens, the difference is almost always a template path: the node id or the
output name does not match the edge you drew. [Troubleshooting](./05-troubleshooting.md)
covers it.

---

**Next**: [Discoverability](./14-node-discoverability.md)
