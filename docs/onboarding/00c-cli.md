---
sidebarTitle: "The unoverse CLI"
title: "The unoverse CLI"
---

One CLI operates your universe: setup, daily development, and deployment. It ships at the root of your repository, and `unoverse help` prints this list in your terminal. Authoring (nodes, design, prompts) lives in **Studio**, not here.

<Note>
Run `./unoverse` (with the `./`) the first time. After `init`, the CLI installs itself to your PATH and `unoverse` works from anywhere. Run it with no arguments for a live dashboard of your universe.
</Note>

## Your first hour

The complete path from a fresh clone to a running universe:

```bash
# LOCAL — run it on your machine
./unoverse init          # wizard: DOCR token, database, Redis, auth → writes .env
./unoverse start         # pull images, start every service
./unoverse db-setup      # apply database migrations
./unoverse check         # green across the board? you're running
./unoverse open canvas   # meet your universe
```

When you're ready for a server, three more:

```bash
./unoverse ground        # prefills terraform.tfvars from your cloud CLI (doctl or aws)
# fill the FILL_ME lines, then in infra/<ground>: terraform init && terraform apply
./unoverse deploy init   # first time: install + db + verify
./unoverse deploy        # every deploy after that
```

If anything misbehaves at any point: `./unoverse doctor`.

## Setup

Get a fresh clone running, and diagnose it when something is off. The database commands run once at first install; after that you should rarely need them.

| Command | What it does |
| --- | --- |
| `unoverse init` | Interactive setup wizard. Asks for your DOCR token, database, Redis, and auth credentials, writes `.env`, logs into the registry, and pulls all platform images. |
| `unoverse db-setup` | Runs database migrations and seeds. Tracked and idempotent; safe to re-run, but a one-time step in practice. |
| `unoverse db-verify` | Verifies the database schema matches what the platform expects. |
| `unoverse doctor` | Diagnoses environment issues across the stack: Docker, env files, containers, ports, database. Your first stop when something is off. |

## Platform

Start, stop, and watch the running platform.

| Command | What it does |
| --- | --- |
| `unoverse` | No arguments: a live dashboard of your universe. |
| `unoverse start` | Starts all services. |
| `unoverse stop` | Stops all services. |
| `unoverse check` | Runs the full health check: containers, health endpoints, built packages, loaded nodes, **Canvas** reachability. (`unoverse status` is an alias.) |
| `unoverse logs` | Opens the Dozzle log viewer. `unoverse logs <service>` streams one service's logs in the terminal. |
| `unoverse update` | Pulls the latest platform images, rebuilds packages, and restarts. `unoverse update nodes` rebuilds node packages only, no image pull. |
| `unoverse open` | Opens a service in your browser: `unoverse open canvas`, `open api`, or `open logs`. |

<Note>
`unoverse update` updates the platform only. Your own work, the nodes, design, and prompts you build in **Studio**, is never touched.
</Note>

## Development

The daily loop: bring the platform up and build your packages.

| Command | What it does |
| --- | --- |
| `unoverse dev` | The daily starter: brings the platform up if needed, installs workspace dependencies, and builds your node packages so the platform loads them. |
| `unoverse build` | Builds all node packages and restarts services. `unoverse build <package>` builds just one, for example `unoverse build @unoverse-platform/my-node`. |
| `unoverse key` | Issues, lists, and revokes publish keys, the credential **Studio** uses to publish to this universe. |
| `unoverse publish assets <project>` | Publishes a project's static assets. |

## Deployment

From your laptop to your server. Provision with Terraform first (`ground` writes the input file); after that `unoverse deploy` is the whole job, and the sub-commands re-run one piece on its own.

| Command | What it does |
| --- | --- |
| `unoverse ground` | Prefills `terraform.tfvars` from your cloud CLI: your IP, SSH keys, existing Postgres clusters (doctl), or region, key pairs, and the Route53 zone (aws). `ground do` / `ground aws` picks explicitly. |
| `unoverse deploy` | Deploys the platform to your server: pulls the latest images and restarts. |
| `unoverse deploy init` | First-time setup: install, database, verify. One command after `terraform apply`. |
| `unoverse deploy db` | Re-runs database setup on the server. |
| `unoverse deploy test` | Runs a connectivity test against the deployed platform. |
| `unoverse deploy harden` | Security hardening, when a universe graduates from POC: SSH keys-only, fail2ban, automatic security updates. Never touches app ports or key-based root SSH, so future deploys and MCP clients keep working. |

TLS and the firewall are not CLI jobs: your ground's Terraform owns them (load balancer certificate, cloud firewall). See [Deployment](./08-deployment.md) and the [Runbooks](../runbooks/overview.md).
