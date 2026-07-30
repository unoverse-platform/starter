# Unoverse Starter

Your workspace for building on the **Unoverse platform**. A self-hosted AI
platform where you compose agent-powered apps out of three kinds of things:

- **Workflows**. Built visually on the **Canvas**, wiring nodes into agents,
  tools, and data flows
- **UI as data**. Components and templates written as JSON definitions
  (no React, no CSS), rendered live by the platform's SDK
- **Behavior**. Agent skills and prompt blocks in plain markdown

The platform services run as Docker images. **This repo operates your
universe** — authoring (components, templates, nodes, skills) happens in
**Studio**, which manages its own projects and publishes to the universe.

## Get your copy

One line — the CLI asks what you're building and scaffolds it:

```bash
npm create unoverse@latest
```

**Most people want a Studio project** (authoring components, nodes, and agent
skills) — the wizard's default, no credentials needed. This universe kit is the
**operator tier**: the wizard asks for your registry access token (from your
Unoverse admin) and validates it before downloading — the platform's images
only pull with it, so there is nothing to run without one.

<details><summary>Prefer GitHub?</summary>

This repo is also a template: **Use this template → Create a new repository**,
then clone your copy. You'll enter the same registry token at `./unoverse init`.
</details>

## Prerequisites

- **Docker** + Docker Compose
- **Node.js 20+** and npm
- A **read-only registry token** from your platform admin (for pulling the
  platform's Docker images)
- A **Postgres** database, **Redis**, and an **OIDC** app (Auth0 or similar).
  All configured in `.env` (`.env.example` documents every variable)

## Quick start

```bash
./unoverse init        # setup wizard: env config + registry login + image pull
./unoverse start       # start the platform
./unoverse db-setup    # apply database migrations
./unoverse check       # verify: services, health, node catalog, bundles
```

Then open:

| Surface | URL |
|---|---|
| **Canvas**. Visual workflow builder | http://localhost:3001 |
| **API**. The platform's public listener | http://localhost:4105 |
| **Logs** (Dozzle, live container logs) | http://localhost:8080 |

## New here? Follow the onboarding

**[`docs/onboarding/`](docs/onboarding/README.md)** walks you from zero to
shipped, in order: Studio → the platform → the CLI, then the numbered
challenges: your first agent → your first node → ingesting content →
components & templates → MCPs → a client app → deployment.
Start at [`00a-studio.md`](docs/onboarding/00a-studio.md).

## What you build — and where

Nothing you author lives in this repo. The split:

| You want to | Where | How it reaches the universe |
|---|---|---|
| Build workflows | **Canvas** (running platform) | saved live |
| Author components, templates, styles, nodes, skills | **Studio** (its own app + projects) | publish from Studio (publish key: `unoverse key`) |
| Install the design system & first-party nodes | **Studio → Marketplace** | per item, database-driven, no restart |
| Operate and deploy the platform | **this repo** (`unoverse` CLI, `infra/`, `ansible/`) | `unoverse deploy` / `update` |

### Build with Claude Code

This repo ships an authoring skill (`.claude/skills/unoverse-create`) **and a
builder MCP registration** (`.mcp.json`). Open the repo in
[Claude Code](https://claude.com/claude-code) and ask for what you want:

- *"create a pricing card component"*, *"add a node that calls our inventory
  API"*, *"write a returns-handling skill"*: Claude writes the artifacts,
  following the platform's authoring rules, validation, and deploy loop.
- *"build me a workflow that …"*: Claude connects to the platform's **builder
  MCP** and builds the workflow live on your Canvas, one tested stage at a
  time. You create a new empty workflow in Canvas, give Claude its id
  (`wf-xxxxxx` from the URL), and watch it build in your browser.

For the workflow builder: the platform must be running (`./unoverse start` —
the builder is served on `localhost:4106`, reachable from this machine only),
and approve the `unoverse-builder` server the first time Claude Code asks.

### Docs map

| Read | For |
|---|---|
| [`docs/onboarding/`](docs/onboarding/README.md) | guided path through your first agent, node, component, and deploy |
| [`docs/nodes/`](docs/nodes/README.md) | complete node development guide (types, patterns, credentials, testing) |
| [`docs/design/`](docs/design/README.md) | the design learning journey: build components & templates as SDUI data, state model, tokens, Studio, validate & ship |
| `docs/unoverse/` | deep reference behind the journey ([AUTHORING](docs/unoverse/UNOVERSE_AUTHORING.md), [STATE_MODEL](docs/unoverse/UNOVERSE_STATE_MODEL.md), layers, conformance) |
| [`docs/runbooks/`](docs/runbooks/README.md) | operations: database, hardening, HTTPS, observability, restarts |

## Platform commands

| Command | Purpose |
|---------|---------|
| `unoverse init` | Interactive setup wizard |
| `unoverse start` / `unoverse stop` | Start / stop the platform |
| `unoverse check` | Health check: services, endpoints, node catalog, bundles |
| `unoverse logs [service]` | Stream logs |
| `unoverse update` | Full update: git sync + pull images + rebuild + restart |
| `unoverse doctor` | Diagnose issues |
| `unoverse db-setup` | Apply database migrations |
| `unoverse key` | Publish keys for Studio |
| `unoverse ground` | Prefill terraform.tfvars from your cloud CLI (deployment) |
| `unoverse deploy init` / `deploy` | First server setup / every deploy after |

## Something wrong?

1. `./unoverse doctor` then `./unoverse check`
2. `./unoverse logs unoverse` (or Dozzle) for errors
3. Node built but not appearing? The catalog loads at boot —
   `docker compose restart unoverse`
4. Still stuck: `docs/nodes/05-troubleshooting.md` and `docs/runbooks/`

## Production

Terraform provisions everything (`infra/digitalocean` or `infra/aws` — VM,
load balancer + TLS, firewall, Postgres, Redis), then two commands:

```bash
./unoverse ground        # prefill terraform.tfvars from your cloud CLI
# fill the FILL_ME lines, terraform apply, then:
./unoverse deploy init   # install + database + verify
```

Update a running server with `./unoverse update`. See
[`docs/onboarding/08-deployment.md`](docs/onboarding/08-deployment.md) and
[`docs/runbooks/`](docs/runbooks/overview.md).
