---
sidebarTitle: "Networking"
title: "Networking"
mode: "wide"
---

Traffic reaches a universe through a load balancer. It holds the certificate for your
domain, terminates HTTPS, and forwards to the engine. The machine behind it is not reachable
from the internet.

On the two cloud grounds, **the Terraform creates the load balancer for you**, configured to
the requirements below. On your own hardware, you bring one.

| Where | The front door |
| --- | --- |
| AWS | An Application Load Balancer with an ACM certificate, created by the module |
| DigitalOcean | A load balancer with a managed Let's Encrypt certificate, created by the module |
| Your own hardware | Whatever you already run: nginx, HAProxy, F5, your API gateway |

## If you bring your own front door

The shipped modules already satisfy all four of these. They exist for the on-premises case,
where your terminator is yours, and the first one is the one that gets missed.

**Idle timeout of an hour or more.** The platform holds long-lived connections for streaming
and live updates, and most proxies default to 60 seconds, which severs them. Where the
timeout is capped below that, as DigitalOcean caps it at 600 seconds, clients must reconnect
cleanly, and that belongs in your acceptance test.

**Access logs off, for now.** A proxy logs full URLs, and one of the platform's connections
still carries its token in the query string. Until that moves to a header, the logs are a
place a token could land. This is tracked and will be lifted.

**Health checks against `/health`.** Nothing else.

**Forward 443 to `:4105`.** The engine is the only thing the internet ever reaches.

None of these make the front door load bearing for security. The authentication gate is
inside the application, so swapping one terminator for another is always a contained change.

## Ports

| Port | Open to | Why |
| --- | --- | --- |
| 443 | The internet, at the load balancer | The single public surface |
| 3001 | Your operator address. Plus the load balancer, when `canvas_public` is on | **Canvas** |
| 22 | Your operator address | SSH, deploys, issuing publish keys |
| 8080 | Your operator address | The log viewer, on small deployments |
| 4106 | Loopback on the VM | The builder surface. Never routable, by construction |

**Canvas has a door per audience.** Operators reach it directly from a nominated address, in
the same trust ring as SSH. A POC that turns on `canvas_public` also serves it through the
load balancer over HTTPS, and each cloud page shows exactly how:
[AWS](./aws.md) host-routes it, [DigitalOcean](./digitalocean.md) puts the port in the URL.

## How a node reaches an external service

Your nodes run inside the engine, and when one calls an API it makes an ordinary HTTPS
request straight out of the VM. There is no API gateway, no egress proxy and no broker in
between.

That is a deliberate choice. A gateway would be another component to run, another place for
credentials to sit, and another thing between a failing call and the person debugging it.
The controls live where the call is made instead.

**Every host is declared.** A node package lists the hosts its nodes may call. The list is
deny-by-default and HTTPS-only, so a node cannot reach anywhere that is not written down.

**The list is checked twice.** Once when the package is linted, and again at run time after
the URL has been built from your settings and the incoming data. The second check is the one
that matters: it means a node cannot assemble its way to an undeclared host from a template,
because the check happens on the final URL rather than on the pattern.

**A credential never travels in clear text.** A request carrying one to a non-HTTPS URL is
refused outright rather than downgraded.

**The node holds no key.** Credentials are decrypted at the moment of the call and handed to
that node alone. A node receives only what it declared, so two nodes in one workflow cannot
read each other's keys.

**A reviewer sees the list before it runs.** Publishing a node shows the hosts it wants to
call, and a node that later reaches for a new one goes back to pending rather than through.

So the question a security review usually asks, which is what stops a third-party node
calling somewhere it should not, has an answer that does not depend on network equipment.
The allowlist is part of the node's definition, it is sealed into the content hash with
everything else, and it is enforced on the request itself.

Nodes are documented for developers in [Who Can Run It](../nodes/15-who-can-run-it.md) and
[Credentials](../nodes/04-credentials.md).

## What a universe must reach outbound

A universe is not a closed system. Four destinations are hard requirements, and an
egress-restricted network has to allow them explicitly. Each provider's Terraform states
them.

| Destination | Why | If it is blocked |
| --- | --- | --- |
| The container registry | Platform images | Deployments and upgrades fail |
| `registry.npmjs.org` | Marketplace node packages, installed at run time | Nodes go silently missing after a restart |
| Your identity provider | Verifying token signatures | Every request fails authentication |
| Your AI providers | The actual work | Agents cannot run |

The npm one is worth reading twice. A universe installs node packages at run time, with the
database as the record of what should be installed. A blocked registry does not fail loudly
at deploy, it produces a universe that comes back from a restart missing capability.

## Client applications

Embeds, chat widgets and demo channels are static builds. They have no server and no
secrets, they never run on the universe VM, and they never open a port.

They talk to the same public surface as everything else. Signed-in users authenticate
against your identity provider, and anonymous visitors arrive through a workflow whose
trigger allows it.

When you host one, a single input has to agree in three places: the list of origins. It
feeds CORS on the API, the callback and logout URLs on your identity provider's client, and
the frame-ancestors policy where the app is hosted. The end state for these apps is a
one-line embed on somebody else's page, so treat cross-origin as permanent rather than as a
development convenience.

---

**Next**: [Data and State](./data.md)
