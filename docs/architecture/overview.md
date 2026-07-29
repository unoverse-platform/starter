---
sidebarTitle: "Overview"
title: "Architecture"
mode: "wide"
---

A universe is one VM, a Postgres database, a Redis instance, and four platform images. That
is the whole system, at every size.

This section is the detail behind that sentence: what runs, what it talks to, how it is
provisioned, and what a security review will ask you.

## What runs

<div className="figure-wide">
<Frame caption="The four containers on the VM, and what each one is reachable from. Click to enlarge.">
  <img src="/images/architecture-vm.svg" alt="Inside the universe VM" />
</Frame>
</div>

**unoverse** is the engine. Your Agents run here, your workflows execute here, and the
platform's MCP surface is served from here. It is the only service the internet reaches.

The workflow engine is not a separate service. It runs in the same process, behind the MCP
surface, and has no listener of its own. That consolidation is why a universe is four
containers rather than seven.

**Canvas** is where you build and observe Agents. It is an operator tool, in the same trust
ring as SSH, reachable only from an address you nominate.

**Memory** keeps user profiles and open tasks, so an Agent can reason about the same person
across weeks.

**Spatial ML** maintains the semantic map behind **Spatial**.

**Studio** does not appear here. It runs on a developer's own machine, reads their files off
disk, and publishes to a universe over the API. It is never deployed.

## Ports and trust zones

Four zones, and which one a service is in is the whole of its network exposure.

| Port | Zone | Carries |
| --- | --- | --- |
| 443 | The internet | Everything a client does, forwarded to `:4105` |
| 22 | Operator address | SSH, deploys, issuing publish keys |
| 3001 | Operator address | **Canvas** |
| 8080 | Operator address | The log viewer, on small deployments |
| 4104 | Blocked at the firewall | **Memory** |
| 5001 | Blocked at the firewall | **Spatial ML** |
| 4106 | Loopback | The builder MCP surface, never routable |

**Canvas is an operator tool, not a public page.** It is not on the load balancer. You reach
it directly, from the address you nominated, in the same trust ring as SSH and the log
viewer. It then talks to the platform over the public surface like any other client.

**Two of those are worth reading carefully.** `4104` and `5001` are published on the VM
rather than bound to loopback, so what keeps them private is the cloud firewall's
default-deny, not the way the container is configured. That is a real control and it is
enforced in your cloud account, but it is one layer rather than two. Binding them to the
Docker network is tracked work.

The gate is in the application, not in the proxy. That matters when a review asks what
happens if the load balancer is misconfigured: the answer is that requests still fail
authentication, because nothing about the proxy is load bearing.

## Your code and the platform stay separate

The platform runs on the VM as Docker images, pulled from the registry by tag. You never
fork it, and it never writes to your folders.

| | Ships as | Updated by |
| --- | --- | --- |
| The platform | Docker images from the registry | Pulling a new tag |
| Your interfaces, skills and prompts | Rows in your universe's database | Publishing from **Studio** |
| Your nodes | Rows, plus npm packages installed at run time | Publishing, then acceptance |
| Your workflows | Rows | Building them on the **Canvas** |

Nothing you author rides inside an image. An image carries code and only code, which is why
a platform upgrade cannot disturb your content and a content change cannot require a
deployment.

## State

All state is in Postgres and Redis. The services hold none of their own, apart from the
engine's in-process session registry, which is the reason a universe runs one engine today.

Redis is the shared-state backbone, and two services use it: the engine, and **Memory**,
which reads its ambient stream of observations from there.

It is always provisioned by the stack rather than brought by you, because the platform owns
its version and its TLS posture.

Postgres can be yours if you have one. [Data and State](./data.md) covers the rules that
come with that, including a connection budget that is not optional.

## Where to go next

| | |
| --- | --- |
| [Deployment Options](./deployment-options.md) | Three sizes, what each one really holds, and what is deliberately not offered |
| [Provisioning with Terraform](./terraform.md) | Five inputs, one command, and the file it hands you |
| [Networking](./networking.md) | TLS, ports, and the outbound hosts a universe must reach |
| [Data and State](./data.md) | Postgres, Redis, the connection budget, backups |
| [Security Posture](./security.md) | What a reviewer is told, and what is still open |
| [Environments and Promotion](./environments.md) | Dev, UAT and production, and what never moves between them |
