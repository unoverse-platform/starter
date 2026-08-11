# Unoverse Starter

Your workspace for operating an **Unoverse** universe: a self-hosted AI platform
where agent-powered apps are composed from three kinds of things.

- **Workflows**, built visually on the **Canvas**, wiring nodes into agents, tools
  and data flows
- **UI as data**, components and templates written as YAML definitions (no React,
  no CSS), rendered live by the platform's SDK
- **Behavior**, agent skills and prompt blocks in plain markdown

**This repo operates your universe.** Authoring happens in **Studio**, which keeps
its own projects and publishes to the universe. The platform services run as
Docker images.

## Documentation

Everything is at **[docs.unoverse.ai](https://docs.unoverse.ai)**. This repo ships
no docs folder, so the site is the one source.

| Start here | For |
|---|---|
| [Onboarding](https://docs.unoverse.ai/onboarding/how-it-fits-together) | Zero to shipped, in order: Studio, the platform, the CLI, then your first agent, node, component, MCP and deploy |
| [Design](https://docs.unoverse.ai/design/overview) | Components and templates as SDUI data: state model, tokens, Studio, validate and ship |
| [Nodes](https://docs.unoverse.ai/nodes/overview) | Node development: manifests, credentials, packaging, testing |
| [Architecture](https://docs.unoverse.ai/architecture/overview) | Deployment options, Terraform, cloud targets, security |
| [Runbooks](https://docs.unoverse.ai/runbooks/overview) | Operations: database, hardening, HTTPS, observability, restarts |

New here? Start at [How it fits together](https://docs.unoverse.ai/onboarding/how-it-fits-together).

## Get your copy

One line. The CLI asks what you are building and scaffolds it:

```bash
npm create unoverse@latest
```

**Most people want a Studio project** (authoring components, nodes and agent
skills), which is the wizard's default and needs no credentials. This universe kit
is the **operator tier**: the wizard asks for your registry access token (from your
Unoverse admin) and validates it before downloading. The platform's images only
pull with it, so there is nothing to run without one.

<details><summary>Prefer GitHub?</summary>

This repo is also a template: **Use this template, Create a new repository**, then
clone your copy. You enter the same registry token at `unoverse create`.
</details>

## Prerequisites

- **Docker** and Docker Compose
- **Node.js 20+** and npm
- A **read-only registry token** from your platform admin, for pulling images
- A **Postgres** database, **Redis**, and an **OIDC** app (Auth0 or similar), all
  configured in `.env` (`.env.example` documents every variable)

## Quick start

```bash
unoverse start    # registry login, image pull, boot, migrations
unoverse check    # verify: services, schema, endpoints, node catalog
```

`start` migrates the database itself, so there is no separate setup step.

| Surface | URL |
|---|---|
| **Canvas**, visual workflow builder | http://localhost:3001 |
| **API**, the platform's public listener | http://localhost:4105 |
| **Logs** (Dozzle, live container logs) | http://localhost:8080 |

## What you build, and where

Nothing you author lives in this repo:

| You want to | Where | How it reaches the universe |
|---|---|---|
| Build workflows | **Canvas** (running platform) | saved live |
| Author components, templates, styles, nodes, skills | **Studio** (its own app and projects) | publish from Studio |
| Install the design system and first-party nodes | **Studio, Marketplace** | per item, database-driven, no restart |
| Operate and deploy the platform | **this repo** (`unoverse` CLI, `infra/`) | `unoverse deploy` / `unoverse update` |

### Build with Claude Code

This repo registers the **builder MCP** (`.mcp.json`), and the authoring skill
arrives with the CLI (`unoverse create` writes it, `unoverse update` refreshes it).
Open the repo in [Claude Code](https://claude.com/claude-code) and ask:

- *"create a pricing card component"*, *"add a node that calls our inventory API"*:
  Claude writes the artifacts following the platform's authoring rules and
  validation.
- *"build me a workflow that ..."*: Claude connects to the builder MCP and builds it
  live on your Canvas, one tested stage at a time. Create an empty workflow in
  Canvas, give Claude its id (`wf-xxxxxx` from the URL), and watch it build.

The platform must be running for the builder (`unoverse start`; it is served on
`localhost:4106`, reachable from this machine only). Approve the
`unoverse-builder` server the first time Claude Code asks.

## Commands

| Command | Purpose |
|---------|---------|
| `unoverse start` / `unoverse stop` | Start / stop the platform |
| `unoverse check` | Health, schema and environment check in one |
| `unoverse logs [service]` | Stream logs |
| `unoverse update` | Full update: sync, pull images, rebuild, restart |
| `unoverse ground` | Prefill terraform.tfvars from your cloud CLI |
| `unoverse deploy` | Build the infrastructure and ship the platform |
| `unoverse destroy` | Tear down provisioned infrastructure |

## Something wrong?

1. `unoverse check`, which runs the health, schema and environment diagnosis
2. `unoverse logs unoverse` (or Dozzle) for errors
3. Node built but not appearing? The catalog loads at boot:
   `docker compose restart unoverse`
4. Still stuck: [Troubleshooting](https://docs.unoverse.ai/nodes/troubleshooting)
   and the [Runbooks](https://docs.unoverse.ai/runbooks/overview)

## Production

Terraform provisions everything (`infra/digitalocean` or `infra/aws`: VM, load
balancer and TLS, firewall, Postgres, Redis), then:

```bash
unoverse ground     # prefill terraform.tfvars from your cloud CLI
# fill the FILL_ME lines, terraform apply, then:
unoverse deploy     # first run: install, database, verify, then ship
```

Update a running server with `unoverse update`. Full detail in
[Deployment](https://docs.unoverse.ai/onboarding/deployment) and the
[Runbooks](https://docs.unoverse.ai/runbooks/overview).
