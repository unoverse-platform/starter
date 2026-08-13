# unoverse starter

Your workspace for operating an unoverse universe. The platform services run as
Docker images; this repo holds the compose file that runs them, your `.env`, and
the Terraform that provisions a server.

Nothing you author lives here. Workflows are built on the **Canvas**. Components,
nodes and agent skills are authored in **Studio** and published to the universe.
Ready-made nodes and the design system install from the **Marketplace**.

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

## Prerequisites

- **Docker** and Docker Compose
- **Node.js 20+** and npm
- A **read-only registry token** from your platform admin, for pulling images
- A **Postgres** database, **Redis**, and an **OIDC** app (Auth0 or similar), all
  named in `.env` (`.env.example` documents every variable)

## Quick start

```bash
unoverse start    # registry login, image pull, boot, migrations
unoverse check    # services, schema, environment
```

`start` migrates the database itself, so there is no separate setup step. A new
universe holds nothing until you install from the **Marketplace** in **Studio**:
[Install from the Marketplace](https://docs.unoverse.ai/onboarding/marketplace-nodes).

| Surface | URL |
|---|---|
| **Canvas**, visual workflow builder | http://localhost:3001 |
| **API**, the platform's public listener | http://localhost:4105 |
| **Logs** (Dozzle, live container logs) | http://localhost:8080 |

Don't have a copy yet? `npm create unoverse@latest` runs the wizard. This universe
kit is the operator tier, so it asks for the registry token before downloading.

## Commands

`unoverse` on its own prints this list, current for the version you have.

| Command | Purpose |
|---|---|
| `unoverse create` | Start something new, here |
| `unoverse studio` | Author components, nodes and agent skills |
| `unoverse where` | Links to this universe, checked live |
| `unoverse update` | Update the CLI, then refresh a running universe's images |
| `unoverse start` / `stop` | Start it (`--pull` for the latest images) / stop it |
| `unoverse check` | Health, schema and environment in one |
| `unoverse logs [service]` | Stream logs |
| `unoverse deploy <cloud>` | Ship it to a server (`unoverse deploy aws`) |
| `unoverse destroy <cloud>` | Take it down, showing what goes and what stays |
| `unoverse db-allow` | Let this machine reach the database, after a network change |

## Build with Claude Code

This repo registers the builder MCP (`.mcp.json`), and the authoring skill arrives
with the CLI. Open the repo in [Claude Code](https://claude.com/claude-code) and ask
for a component, a node, or a workflow built live on your Canvas. The platform has
to be running, and you approve the `unoverse-builder` server the first time Claude
Code asks.

## Something wrong?

1. `unoverse check`, which runs the health, schema and environment diagnosis
2. `unoverse logs unoverse`, or Dozzle, for errors
3. Still stuck: [Troubleshooting](https://docs.unoverse.ai/nodes/troubleshooting)
   and the [Runbooks](https://docs.unoverse.ai/runbooks/overview)

## Production

Terraform provisions the server, load balancer, TLS and firewall from
`infra/digitalocean` or `infra/aws`, then `unoverse deploy` ships the platform to
it. Steps, inputs and the order to run them in:
[Deployment](https://docs.unoverse.ai/onboarding/deployment).
