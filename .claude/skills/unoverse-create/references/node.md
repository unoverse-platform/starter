# Playbook: custom workflow nodes

**Read first, in order:**

1. `docs/nodes/CLAUDE.md`: the authoritative agent guide. The folder, the eight
   non-negotiable rules, every file with an example, and the lint-error-to-fix table.
2. `docs/nodes/manifest-nodes.md`: the format in full, including the run context.
3. `docs/nodes/node-discoverability.md`: **read before writing `whenToUse`**.
4. As needed: `credentials.md`, `who-can-run-it.md`, `config-schema.md`, `service-connectors.md`,
   `mcp-services.md`, `signal-routing.md`, `testing-nodes.md`.

This playbook adds the workflow around those docs. It never overrides them.

## A node is YAML

There is no TypeScript, no `src/`, no `package.json`, no build and no publish step. A node
is a folder of YAML files that the platform interprets.

**Never write a code node.** If the format cannot express what is needed, the platform is
missing a capability. Say so and stop, rather than reaching for code.

```
apps/unoverse/nodes/<package>/
  package.yaml              # name, category, allowedHosts, requires
  credentials/
    <name>Credential.yaml   # the SHAPE of a credential, never a value
  shared/                   # fragments several nodes $ref, and helpers: they call
  nodes/
    <NodeName>/
      node.yaml             # what it IS       (the only REQUIRED file)
      interface.yaml        # what it CONNECTS TO
      config.yaml           # the settings form
      api/
        run.yaml            # the calls it makes, ALWAYS a list
        events.yaml         # everything that leaves the node
      test.yaml             # a fixture that runs
```

## Before writing anything

**Read the closest published node and mirror it.** They are all public:

**[marketplace/definitions/nodes](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes)**

| If the node needs | Read |
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

Closer to a real service: [airtable](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/airtable), [gtm](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/gtm),
[hubspot](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/hubspot), [salesforce](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/salesforce), [search](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/search),
[slack](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/slack), [x-search](https://github.com/unoverse-platform/marketplace/tree/main/definitions/nodes/x-search).

Adding a node to an existing package in the user's own repo is usually right. Create a
package only for a new integration.

## Workflow

1. **Decide `kind`.** One call, one reply is `PromiseNode`. Streaming or a tool loop is
   `CallbackNode`. Lint verifies it against the transport and `toolExchange`.
2. **Write `node.yaml`.** Treat `whenToUse` as make-or-break: it decides whether the node is
   ever offered. Outcome first, disqualify by property, never name another node, wiring fact
   last. Then answer who may run it, which is compulsory on every node:

   ```yaml
   auth:
     required: false      # adds no requirement of its own; does NOT mean public
     # role: crm:write    # optional; implies required: true
   ```

   `required: false` is right for almost every node: the trigger already decided who was let
   in. See `docs/nodes/who-can-run-it.md`.
3. **Write `interface.yaml`.** Name outputs for what they carry, because those names become
   what someone types in a template.
4. **Write `config.yaml`.** Every value the workflow supplies needs `ui:field: template`. A
   `description` says what the setting does, not what it is called. Then add the two
   run-authorization fields, which every node carries identically:

   ```yaml
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
   ```

   These are the workflow BUILDER's control, per box on a canvas, separate from
   `node.yaml`'s `auth`, which is your floor. The executor takes the stricter of the two. A
   role usually belongs here rather than in the manifest: `finance:approve` is a claim one
   deployment's identity provider mints, and a published node cannot know it. Add both to
   `ui:order`.
5. **Write `api/run.yaml`.** A list, each entry named. Include `error` wherever the service
   can answer 200 with a failure body. Where one call is really many, name the capability on
   the call rather than trying to express a loop: `paginate`, `chunk`, `poll` or `state`.
   See `docs/nodes/calls-that-loop.md`, and declare each one in `requires`. A call
   authenticates with `credential: { scheme, token }`, which is OUTBOUND: how the node proves
   itself to the vendor. It is not `node.yaml`'s `auth`, which is who may run the node.
6. **Write `api/events.yaml`.** One row per output connector, in the order `interface.yaml`
   declares them. Streaming rows need `match`, and usually `accumulate: true`.
7. **Add the host** to `allowedHosts` in `package.yaml`, and the credential file if the
   service needs a key.
8. **Write `test.yaml`.** Assert the shape, never exact words.

## Verify

```bash
unoverse node lint
unoverse node test <NodeType>
```

Both must pass before the node is done. Lint names the rule and the page behind it, so read
the message rather than guessing.

`node test` calls the real service and needs no platform running. It reads keys from `.env`
as `<CREDENTIAL>_<FIELD>` in upper snake case, so `openAICredential.apiKey` is
`OPENAI_API_KEY`.

A node that lints but has never run is not done. Running it is the only check that proves
the manifest describes the real service rather than something merely coherent.

## Things that go wrong

- **A template resolved to empty.** Nothing errors. The node id or the output name does not
  match a real edge. There is no `input.*` root, and array indexes are dot segments
  (`records.0.Name`), never brackets.
- **A number arrived as a string.** A field that is exactly one `{{ path }}` keeps its type.
  Anything with text around it becomes a string.
- **An output stays empty.** No row in `events.yaml` emits to it.
- **A downstream node gets one word at a time.** The streaming row needs `accumulate: true`.
- **The request was refused before it left.** The host is not in `allowedHosts`.
- **An expression was rejected.** The sandbox has no `new`, so no `new Date(...)`. Use
  `Date.now()` and `Date.iso(ms)`. Nothing mutates either: `.at(-1)` not `.pop()`,
  `.toSorted()` not `.sort()`. No spread in call arguments: `reduce` into an object rather
  than `Object.assign({}, ...list)`.
- **An expression grew past a few lines.** Give it a name. Any `shared/*.yaml` may declare
  `helpers:`, and every expression in the package can call them:

  ```yaml
  # shared/helpers.yaml
  helpers:
    row:
      args: [r]
      body: "return { id: r.id, title: r.title }"
  ```
  ```yaml
  returns: "return response.items.map(helpers.row)"
  ```

  A helper sees ONLY its arguments and its sibling helpers — never `config`, `credentials`
  or the caller's scope. Same sandbox, no extra authority.

## Do not

- Write TypeScript, a `package.json` or a build step for a node
- Put a credential value in any file
- Hard-code instruction text. Use `{{prompt.<blockName>}}` so it tracks the block
- Name another node in `whenToUse`
- Set `cacheable: true` on anything effectful or non-deterministic
- Claim a capability the platform does not implement
- Write `auth:` on a call. That key is `credential:`; `auth` on a node is who may RUN it
