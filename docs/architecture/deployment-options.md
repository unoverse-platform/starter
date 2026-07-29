---
sidebarTitle: "Deployment Options"
title: "Deployment Options"
mode: "wide"
---

There are three sizes. They scale the machine and the data stores, not the shape of the
system, so a small universe and a large one run the same images in the same arrangement.

Changing size is a variable, a re-apply, and a redeploy.

## The sizes

| | **small** | **medium** | **large** |
| --- | --- | --- | --- |
| For | Demos, POCs, development universes | First production | High-traffic production |
| VM | 4 vCPU, 16 GB | 8 vCPU, 32 GB | 8 vCPU, 64 GB |
| Postgres | Smallest managed tier | Mid tier | Large tier, HA available |
| Redis | Single node, TLS | Single node, larger | Single node, larger |
| Backups | 7 days, self-purging | 14 days, restore tested | 35 days, restore tested |
| Log viewer | On, operator address only | Off, ship to your own stack | Off, ship to your own stack |

Capacity, stated honestly. A small universe suits demos and small pilots, and its real
ceiling is usually the rate limits of the AI provider rather than the box. A medium
universe is sized for roughly 2,500 connected users and low hundreds of concurrent
executions. A large one is sized for roughly 10,000 connected users and one to two thousand
concurrent executions.

Treat those as planning figures. They are derived from comparable systems and adjusted for
a single engine instance, and they are not measurements of your workload.

## Why large is not simply a bigger machine

The engine is one Node process with one event loop. Cores beyond about eight sit idle as far
as it is concerned, and only serve the containers beside it. So the large tier spends its
budget on memory, on bigger data stores, and on giving **Spatial ML** its own machine when
embeddings grow.

**Large is the vertical ceiling.** Past it the answer is engine work, not a bigger box. That
work is session affinity across instances, and the connection budget in
[Data and State](./data.md) is its prerequisite.

## What is deliberately not offered

Being clear about this is worth more than a menu of tiers nobody has run.

**No multi-VM active/active.** A universe runs one engine instance today. Two would need
session affinity at the entry point and a session registry outside the process, and neither
exists yet. Documents that promised 20,000-user active/active tiers were describing a plan,
not a product, and they have been withdrawn.

**No Kubernetes or ECS.** One VM with Docker Compose is the deployment. It is also the thing
a customer's operations team can read in an afternoon.

**No auth-off mode.** Authentication is always on, because **Canvas** and **Studio** sign
in against it. Letting anonymous visitors reach a workflow is a per-workflow decision made
on the trigger, not a property of the deployment.

**No pipeline at POC tier.** Provisioning is `terraform apply` and deployment is a CLI
command. Wiring those into CI is a decision a customer makes later, on their own terms.

## Where the platform can grow

Two seams exist for real, and they are worth knowing about because they answer most
"what if" questions in a review.

**The identity provider is a variable.** Auth0 today, Entra or Cognito tomorrow, without a
code change. See [Provisioning](./terraform.md).

**Postgres can be yours.** An existing managed cluster, or a database somewhere else
entirely. See [Data and State](./data.md).

## Running it on your own hardware

Nothing about the platform requires a cloud. The images run on a VM you already own, and the
only things the cloud modules were providing are a TLS terminator, a Postgres, and a Redis.

You bring your own entry point, which is the one place an on-premises deployment differs. The
platform ships a requirement rather than a proxy: terminate TLS, forward to `:4105`, and
honour the settings in [Networking](./networking.md). Any of nginx, HAProxy or
F5 does the job, and because the authentication gate is in the application, none of them is
load bearing.

---

**Next**: [Provisioning with Terraform](./terraform.md)
