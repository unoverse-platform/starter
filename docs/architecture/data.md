---
sidebarTitle: "Data and State"
title: "Data and State"
mode: "wide"
---

Everything a universe knows is in Postgres. Everything it coordinates is in Redis. The
machine itself holds nothing worth keeping, and that is the whole design: a universe is its
data stores plus two small artifacts, and the VM is disposable.

## What lives where

| | Postgres | Redis |
| --- | --- | --- |
| Workflows, and the runs of them | Yes | |
| Your components, templates, skills and prompts | Yes | |
| Installed nodes, and what should be installed | Yes | |
| Conversations, memory and traces | Yes | |
| Credentials, encrypted | Yes | |
| Coordination between services: queues, pub/sub, streams | | Yes |
| Live session and streaming state | | Yes |

The database is the source of truth for what a universe has. That is why a universe can
rebuild its installed nodes after a restart, and why nothing you author needs to ride inside
an image.

## Losing the machine

The recovery story falls out of the table above. Rebuild the VM, deploy the images, point
them at the same Postgres and Redis, and the universe is back: workflows, assets,
conversations, installed nodes, all of it, because none of it lived on the machine.

Two artifacts have to survive alongside the database, and they are the ones people forget:

- **The credential encryption key.** Without it, a restored database contains credentials
  that can no longer be read.
- **The Spatial ML models.** They can be rebuilt from your content, but restoring them is much faster.

The one true loss is live state. The engine keeps its session registry in process, so open
sessions drop on a restart and clients reconnect. That is also the reason a universe runs
one engine instance today.

## Postgres can be yours

Three modes, and the first match wins.

| You provide | What happens |
| --- | --- |
| A database URL | Fully external. The URL is used as given |
| The name of an existing managed cluster | Terraform adds this universe's database, user, connection pool and firewall rule to it, and touches nothing else |
| Neither | Terraform provisions a fresh cluster |

The middle one is the common enterprise answer. A platform team that already runs managed
Postgres keeps running it, and the universe becomes another database on it rather than
another cluster to look after.

**What you take on when you bring your own.** Reachability is yours, so the VM must have a
network path to your database and your firewall must allow it. Terraform still opens its own
side. Backups are yours, and outside the windows below. And the connection budget still
applies, measured against your `max_connections` rather than a number Terraform chose.

Postgres 14 or later, and TLS in the URL. That is not negotiable in either direction.

## The connection budget

This section exists because connection exhaustion is the failure that has bitten most often,
and because the arithmetic used to be owned by nobody.

Three pools connect to Postgres, plus migrations while they run.

| Pool | small | medium | large |
| --- | --- | --- | --- |
| Engine | 8 | 20 | 40 |
| Engine, legacy | 4 | 8 | 12 |
| Memory | 4 | 10 | 20 |
| Migrations and operations | 2 | 2 | 4 |
| Reserve | 1 | 10 | 24 |
| **Total** | **19** | **50** | **100** |

The budget travels as configuration, not as code. Picking a size renders three pool
variables into the environment file, and each service reads its own. The totals fit each
tier's ceiling by construction of the size map, so the arithmetic is owned in exactly one
place; edit that map and you own it.

The small tier is where this matters. DigitalOcean's smallest managed Postgres allows around
nineteen usable connections, and the platform's pools would ask for roughly thirty-two if
each were tuned on its own. AWS's smallest allows well over a hundred, which is why the
symptom used to look provider-specific and mysterious.

**On DigitalOcean, Postgres is always behind its managed transaction pooler.** Nineteen
backend connections then serve hundreds of client ones. Two consequences come with that, and
both are handled: connection URLs disable prepared statements, and migrations connect
directly to the database rather than through the pooler.

On AWS, small and medium connect directly, because the headroom is there. A proxy is an
option at the large tier rather than a default.

If you bring your own Postgres and its ceiling is low, put a pooler in front of it. That is
the same advice, applied to a database the platform cannot size for you.

## Backups

| | Window |
| --- | --- |
| small | 7 days, self-purging |
| medium | 14 days |
| large | 35 days |

The windows are provider-native Postgres backups, set by Terraform. The tested restore is
yours: at medium and above, the operating expectation is that a restore has actually been
run, not assumed. A backup that has never been restored is a hope.

Redis is deliberately not backed up. It holds coordination and live state, and there is
nothing in it worth restoring.

## Redis is not an input

Redis is always provisioned by the stack, never brought by you. The platform owns its
version, its TLS posture and where it sits, because it is the shared-state backbone and the
seam that any future multi-instance work stands on. Only Postgres is flexible.

---

**Next**: [Security Posture](./security.md)
