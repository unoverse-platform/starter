---
sidebarTitle: "Architecture"
title: "Platform Architecture"
---

This page is the high-level map of the platform: what runs, how your code stays separate from the platform, and how the same stack scales from a laptop to a distributed deployment.

## The runtime

At its core, unoverse is an MCP server. Every interface you build is served to clients as an MCP app, and every MCP app is powered by a workflow and your custom nodes and services. The implementation is native MCP, not an adapter, so any MCP client works out of the box: ChatGPT, Claude, or your own apps through the SDKs. One protocol carries your Agents, tools, and interfaces to every client.

Everything a client sees is served by the **unoverse** engine; the other services specialize.

![The unoverse runtime](./images/architecture-runtime.png)

[Open the interactive version](./runbooks/architecture-diagrams/10-platform-runtime.html)

- **unoverse** is the engine: where your Agents, your services, and the AI run. It executes your workflows, serves the platform's native MCP surface, and streams live results to clients. Only the MCP surface is public; the workflow engine runs behind it and cannot be reached from outside the server. One public listener, JWT-gated. 
- **Canvas** is where you build, manage, and observe Agents.
- **Studio** is where you design components, templates, and skills. It is a development tool and is not exposed in production.
- **Spatial ML** maintains the 3D semantic map behind **Spatial**.
- **Memory** keeps user profiles and open tasks so Agents can reason about the same user across weeks.

All state lives in Postgres and Redis. The services themselves are stateless, which is what makes scaling and recovery straightforward.

## Your code and the platform stay separate

The platform ships as compiled Docker images. Your work mounts into it:

![Your code and the platform](./images/architecture-code-separation.png)

[Open the interactive version](./runbooks/architecture-diagrams/11-code-separation.html)

You never fork the platform and the platform never touches your folders. Platform updates are an image pull. Your code is discovered automatically at startup.

## From laptop to enterprise, same stack

The images are identical at every tier. Only the topology changes. Development runs on your machine via `unoverse dev`; production scales through three sizing options:

![Deployment tiers: POC, Standard Enterprise, High Availability](./images/architecture-deployment-tiers.png)

[Open the interactive version](./runbooks/architecture-diagrams/01-deployment-tiers.html)

| Tier | Shape | Good for |
|---|---|---|
| POC | 1 VM, all services, optional Caddy reverse proxy for TLS | Demos, development, customer POCs |
| Standard Enterprise | 3 VMs: 2 app (active/active) + 1 dedicated ML, managed Postgres/Redis | 20,000+ connected users, production |
| High Availability | 4+ VMs with N+1 redundancy and automated failover | 50,000+ users, strict availability targets |

Deployment is driven by the same CLI at every tier, backed by Ansible playbooks you can read. The [Runbooks](./runbooks/overview.md) walk through each step, and the [interactive architecture diagrams](./runbooks/architecture-diagrams/index.html) show the full topology, network boundaries, and communication flows.

## Security posture

- Every public request is authenticated. The public surface is JWT-gated; the internal runtime surface is reachable only inside the Docker network.
- Access is role-based.
- Credentials for external services are encrypted at rest and injected into nodes at execution time. Node packages never see raw secrets in config.
- MCP connections are authenticated on both hops: client to platform, and platform to the services your Agents call.
- Agent actions are logged, including the content used to produce each decision, so behavior is auditable after the fact.
- A live log viewer ships with the platform ([Dozzle](./runbooks/07-observability.md)), streaming every service's logs in one place. Enterprise deployments can point the Docker logging driver at their own stack instead: Splunk, ELK, or Datadog.

## Where to go deeper

| Topic | Where |
|---|---|
| Deploying each tier | [Runbooks](./runbooks/overview.md) |
| The interactive diagrams | [Architecture diagrams](./runbooks/architecture-diagrams/index.html) |
| Building on the platform | [Getting Started](./onboarding/01-getting-started.md) |
