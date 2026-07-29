---
sidebarTitle: "The unoverse CLI"
title: "The unoverse CLI"
---

One CLI drives everything: setup, daily development, design tooling, and deployment. It ships at the root of your repository, and `unoverse help` prints this list in your terminal.

<Note>
Run `./unoverse` (with the `./`) the first time. After `init`, the CLI installs itself to your PATH and `unoverse` works from anywhere.
</Note>

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
| `unoverse start` | Starts all services. |
| `unoverse stop` | Stops all services. |
| `unoverse status` | Shows service health at a glance. |
| `unoverse check` | Runs the full health check: containers, health endpoints, built packages, loaded nodes, **Canvas** reachability. |
| `unoverse logs` | Opens the Dozzle log viewer. `unoverse logs <service>` streams one service's logs in the terminal. |
| `unoverse update` | Pulls the latest platform images, rebuilds packages, and restarts. |
| `unoverse open` | Opens a service in your browser: `unoverse open canvas`, `open api`, or `open logs`. |

<Note>
`unoverse update` updates the platform only. Your own code, the nodes, design, and prompts you build in **Studio**, is never touched.
</Note>

## Development

The daily loop: bring the platform up and build your packages.

| Command | What it does |
| --- | --- |
| `unoverse dev` | The daily starter: brings the platform up if needed, installs workspace dependencies, and builds your node packages so the platform loads them. |
| `unoverse build` | Builds all node packages and restarts services. `unoverse build <package>` builds just one, for example `unoverse build @unoverse-platform/my-node`. |

## Design

Tooling for the definitions in `rx/`.

| Command | What it does |
| --- | --- |
| `unoverse new` | Creates an org: `unoverse new org <name>` sets up the folder structure with the default token set, ready to rebrand. |
| `unoverse lint` | Lints your rx/ definitions against the schema and the platform's guard rules, the same rules **Studio** and the conformance checks apply. |

## Deployment

From your laptop to your server. `unoverse deploy` does the whole job: the first run provisions the server, sets up the database, and installs the supporting services. The sub-commands re-run one piece on its own; you rarely need them.

| Command | What it does |
| --- | --- |
| `unoverse deploy` | Deploys your platform to your server: platform images plus your nodes, design, and prompts. |
| `unoverse deploy design` | The fast lane for design changes: rsyncs `rx/` to the server and restarts. No build. |
| `unoverse deploy test` | Runs a connectivity test against the deployed platform. |
| `unoverse deploy init` | Re-runs server provisioning on its own. |
| `unoverse deploy db` | Re-runs database setup on the server. |
| `unoverse deploy caddy` | Re-installs the Caddy reverse proxy for TLS. `deploy caddy-uninstall` removes it. |
| `unoverse deploy umap` | Re-installs the **Spatial** ML service. |
| `unoverse deploy harden` | Re-applies security hardening to the server. |

Deployment is covered step by step in [Deployment](./08-deployment.md) and the [Runbooks](../runbooks/overview.md).
