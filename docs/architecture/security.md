---
sidebarTitle: "Security Posture"
title: "Security Posture"
mode: "wide"
---

This page is written for the review, not for the brochure. Every control below is one you
can find in the code or in the Terraform, and the last section lists what is still open.

## Who owns what

| | Owned by |
| --- | --- |
| The cloud account, the VM, the data stores | You |
| The identity provider and its user directory | You |
| The data, and every credential in it | You |
| The platform images | Us |
| The Terraform that creates the ground | Shipped to you, run by you, in your version control |

There is no hosted control plane in the middle. A universe does not call home, and nothing
about running it depends on our availability.

## Authentication

**Authentication is always on.** There is no deployment mode that turns it off, because
**Canvas** and **Studio** sign in against it.

The gate is default-deny and lives in the application, at the single public listener. Tokens
are verified against your provider's published keys, checking both issuer and audience. A
request that does not present a valid one is refused before anything executes.

Because the check is in the application, no proxy is ever load bearing for security. A
misconfigured load balancer is an availability problem, not an authentication bypass.

Letting anonymous visitors reach a workflow is possible, and it is a per-workflow decision
made on the trigger. Those callers arrive with a synthetic guest identity that carries no
roles, so they fail every role requirement naturally.

## Authorization

Roles are `noun:verb` claims on the caller's token, read from either the roles or the
permissions claim so the same configuration works across providers.

Every node states who may run it, and the block is compulsory rather than optional. That is
the point: a reviewer can tell the difference between a node that was considered and left
open and a node nobody thought about. A node can demand a signed-in caller, or a specific
claim, and the person building the workflow can demand more on top. Neither can loosen the
other, and a node that reaches the executor with nothing declared is treated as requiring
authentication.

[Who Can Run It](../nodes/15-who-can-run-it.md) is the developer-facing version of this.

## Credentials

Credential values are encrypted at rest, per field, and only fields marked secret are
encrypted. They are decrypted at the moment a node runs and handed to that node alone.

A node receives only the credentials it declared. Two nodes in one workflow cannot read each
other's keys, whatever either of them writes, because credentials are addressed by name
rather than discovered.

Nothing an author writes ever contains a value. The manifest names the credential; the value
is entered once in **Canvas** and lives only in the database.

## What a node is allowed to do

A node is YAML interpreted by the platform, not code the platform runs on its behalf. Two
controls bound it.

**Declared hosts.** Every host a node may call is declared in its package. The list is
deny-by-default and HTTPS-only, and it is checked twice: when the package is linted, and
again at run time after the URL has been built. A node cannot construct its way to an
undeclared destination.

**A content hash.** A node's composed definition, including its host list, is hashed. The
hash is checked when the definition is loaded, so a definition that changed after it was
accepted does not quietly run.

Publishing a node reaches a universe as pending rather than live. Whoever runs that universe
sees the hosts it wants to call, the credentials it needs and the access it demands, and
accepts it before it can run. After that first acceptance, iteration is not gated. A node
that reaches for something new pauses again.

## Network posture

Only 443 is open to the internet. SSH, **Canvas** and the log viewer are restricted to an
address you nominate, and the builder surface binds to loopback so it is not routable at
all.

Firewall rules live in the cloud provider rather than on the VM, which removes the class of
problem where a container runtime writes its own rules underneath a host firewall.

Outbound, a universe needs the container registry, the npm registry, your identity provider
and your AI providers. Each provider's Terraform states them, and
[Networking](./networking.md) explains what breaks if one is blocked.

## Secrets and rotation

Every deployment generates its own secrets. Database and Redis passwords are random per
universe, and so is the credential encryption key. None of them is shared between
deployments and none of them is known to us.

Secrets are entered per environment. They are never copied from one environment to another,
which is covered in [Environments](./environments.md).

## Auditability

Agent activity is recorded, including the content that produced each decision, so behaviour
can be reconstructed after the fact rather than inferred.

Small deployments ship with a log viewer, restricted to your operator address. Larger ones
turn it off and point the container logging driver at whatever you already run, whether that
is Splunk, ELK or Datadog.

## Still open

Two items are honest gaps rather than controls. Both are known and both are tracked.

**The credential encryption key has a fallback default in code.** A universe provisioned by
the Terraform is given a generated key, so a correctly provisioned deployment does not use
the default. The fallback should not exist, and removing it is required before any
internet-facing deployment.

**One connection carries its token in the query string.** That is why load balancer access
logs are switched off in the entry point requirements. Moving the token to a header lifts both
the gap and the restriction.

---

**Next**: [Environments and Promotion](./environments.md)
