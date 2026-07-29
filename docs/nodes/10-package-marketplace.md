---
sidebarTitle: "Packages"
title: "Packages"
---

A package is the folder your nodes live in. It carries what they share and what the
marketplace shows.

`package.yaml` describes it, and there is one per package.

```yaml package.yaml
$schema: ../_schema/package.schema.json

name: example
displayName: Example
description: Example integration for unoverse
version: 1.0.0
category: ai
logoUrl: https://example.com/logo.svg

features:
  - Search across your catalogue
  - Read a record by id
  - Streaming responses

allowedHosts:
  - api.example.com

requires:
  credential: [bearer]
  transport: [json]
  executorVersion: ">=1.0.0"
```

`name`, `displayName` and `version` are required. The rest earn their place below.

## What the marketplace shows

| Key | Used for |
|---|---|
| `displayName` | The name someone reads. Short, no scope prefix, no "integration for unoverse" |
| `description` | One line on what the package connects to |
| `category` | Which section it appears under |
| `logoUrl` | A square icon, `.webp` or `.svg` |
| `features` | Three to eight short lines on what someone can **do**, not how it works |

Categories are `ai`, `storage`, `ingest`, `communication`, `cloud`, `flow`, `media`,
`search` and `productivity`.

This is a different list from the `category` on a node. A package category groups it in the
marketplace; a node category describes the job that node does. Both are enums, and confusing
them is a lint error rather than a silently wrong grouping.

You do not list the nodes here. Every `node.yaml` under `nodes/` is found on its own, so the
package cannot disagree with what it actually contains.

## `allowedHosts`: the hosts your nodes may call

Every host any node in this package reaches, and nothing else is permitted.

```yaml
allowedHosts:
  - api.example.com
  - "*.example-cdn.com"
```

Deny by default. A call to a host not on this list is refused with the host named, and
non-https is refused outright, so a key cannot travel in clear text.

`*.example.com` matches exactly one level, so `files.example.com` passes and
`a.files.example.com` does not.

The list is checked when you lint and again at run time, after the URL has been assembled.
That second check matters because a host can itself come from a template, and only the
finished URL can be judged.

It is also what somebody accepts when you publish the package. Keep it short and keep it
honest: a list of two hosts is read and approved in seconds, and a list that quietly grows
is the one that gets questioned.

## `requires`: what the platform must support

What your nodes need from the platform in order to run.

```yaml
requires:
  credential: [bearer]
  transport: [json, sse]
  executorVersion: ">=1.0.0"
```

Publishing refuses the package where the universe cannot satisfy it. Without that, a node
using a newer capability would publish cleanly and then fail when something ran it.

## Sharing what nodes have in common

Two folders sit beside `nodes/`, and both exist so a value has one home.

```
example/
├── package.yaml
├── credentials/
│   └── exampleCredential.yaml
├── shared/
│   ├── endpoints.yaml
│   └── models.yaml
└── nodes/
```

`credentials/` describes each credential the package's nodes ask for. `shared/` holds
fragments more than one node reuses, reached with `$ref`.

```yaml
url: { $ref: endpoints#search }
```

When the API moves an endpoint, one file changes rather than every node.

## When it goes wrong

| What you see | Why |
|---|---|
| Lint: host not declared | A node calls somewhere `allowedHosts` does not list |
| Lint: a node needs a credential the package does not describe | No matching file in `credentials/` |
| Lint: unknown category | A node category used on a package, or the reverse |
| A node calls out and is refused at run time | The URL resolved to a host outside `allowedHosts` |

---

**Next**: [Troubleshooting](./05-troubleshooting.md)
