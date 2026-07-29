---
sidebarTitle: "Azure"
title: "unoverse on Azure"
mode: "wide"
---

<img src="/images/logos/azure.svg" alt="Microsoft Azure" style={{ height: "30px", margin: "0 0 1.25rem" }} />

**Planned, not built.** There is no `infra/azure` module today. This page says what it will
be, so you can judge the fit before it exists.

## What it will create

The same universe, from the same five inputs, using Azure's managed equivalents.

| | |
| --- | --- |
| Compute | A virtual machine, with a network security group |
| Entry point | Application Gateway, with a managed certificate |
| Data | Azure Database for PostgreSQL, and Azure Cache for Redis |
| Identity | Your own Entra tenant |
| Secrets | A generated credential encryption key |

## Why it is a smaller job than it looks

The contract is deliberately narrow. A ground has to produce a machine, a Postgres, a Redis,
a TLS terminator and a rendered environment file. Everything above that line is identical,
because the images, the CLI and every runbook are cloud-blind by design.

Identity is the part that usually makes a port expensive, and it is already solved here.
Entra is an OIDC issuer, so it arrives through the `byo-oidc` input that Auth0 uses today.
The platform never names a provider, and the swap is configuration.

## Using Azure before the module exists

Nothing about the platform requires our Terraform. A universe is a VM running four containers
against a Postgres and a Redis, so an Azure deployment built by your own platform team works
today.

You take on what the module would have done: the network security group, the certificate on
your Application Gateway, the entry point settings in [Networking](./networking.md), and the
connection budget in [Data and State](./data.md).

Tell us if you are doing this. A real deployment is what turns a planned module into a built
one.

---

**Next**: [Networking](./networking.md)
