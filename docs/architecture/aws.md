---
sidebarTitle: "AWS"
title: "unoverse on AWS"
mode: "wide"
---

Everything is created in your own account, by Terraform you keep in your own version
control. There is no hosted control plane and the universe does not call home.

<div className="figure-wide">
<Frame caption="Everything Terraform creates in your AWS account. Click to enlarge.">
  <img src="/images/architecture-aws.svg" alt="Everything Terraform creates in your AWS account. Click to enlarge." />
</Frame>
</div>

<div className="fig-notes">
<div>
<p className="fig-title">Exposure</p>
<ul>
<li><span className="zone" style={{ background: "#d97706" }} /><span>Reached from the internet</span></li>
<li><span className="zone" style={{ background: "#7c3aed" }} /><span>Operator address only</span></li>
<li><span className="zone" style={{ background: "#0f766e" }} /><span>Published on the VM, blocked by the security group</span></li>
</ul>
</div>
<div>
<p className="fig-title">The paths</p>
<ul>
<li><span className="num">1</span><span>A client speaks MCP over HTTPS. 443 is open on the load balancer because that is where TLS terminates; 80 exists only to redirect to it. The load balancer then forwards to the engine on 4105, and the instance itself is not reachable from the internet.</span></li>
<li><span className="num">2</span><span>An operator reaches Canvas through the same load balancer, at unoverse.example.com, which the second host rule forwards to 3001. SSH on 22, the log viewer on 8080, and Canvas direct on 3001 stay open to your address as a fallback, and are the only route when canvas_public is off.</span></li>
<li><span className="num">3</span><span>The VM reaches Postgres on 5432 and Redis on 6379. Nothing else in the account can.</span></li>
<li><span className="num">4</span><span>Tokens are verified against Cognito. Bedrock is called with a scoped IAM user.</span></li>
<li><span className="num">5</span><span>Nodes call out on 443, only to hosts their own package declares.</span></li>
</ul>
</div>
</div>

<Note>
**This is the POC shape: one machine, one availability zone.** Larger deployments keep the same picture and change what sits behind the load balancer, which is where the multiple-instance work will land. [Deployment Options](./deployment-options.md) covers the sizes and what is deliberately not offered yet.
</Note>

## What Terraform creates

| | |
| --- | --- |
| Compute | An EC2 instance with an elastic IP, in two security groups |
| Data | RDS Postgres 16 and ElastiCache Redis 7, each with a generated password |
| Identity | A Cognito user pool, an SPA client, a hosted domain, one group per role, and the first administrator |
| Claims | A pre-token Lambda, so email and roles reach the token |
| AI | An IAM user scoped to Bedrock |
| Secrets | A generated credential encryption key |

## The trust boundary is the security groups

Two groups, and the second one is the point. The data group admits the application group and
nothing else, so neither database is reachable from the internet. RDS is created with public
access switched off rather than merely firewalled away from it.

**The POC uses the account's default VPC on purpose.** There are no private subnets and no
NAT gateway to own, because the boundary is doing the work. A deployment that needs its own
VPC changes where the resources sit, not what protects them.

## Identity is included here

AWS is the one ground where the platform can own the identity provider, and that is why
`auth = cognito` exists.

Terraform creates the user pool, creates one group per role you listed, creates the first
administrator and puts them in every group. The roles exist because the apply ran. Cognito
emails that administrator a temporary password.

The pre-token Lambda is doing real work. Cognito does not put email and group membership
onto an access token by default, and the platform needs both, so the Lambda adds them. Every
other ground reaches the same contract by configuring their own provider.

## What the module actually provisions

| | |
| --- | --- |
| Instance | `t3.xlarge`, Ubuntu 22.04, 100 GB gp3 root volume, Elastic IP |
| Postgres | RDS 16, `db.t4g.small`, single AZ, 20 GB growing to 50, gp3 |
| Backups | 7 days, with a final snapshot taken on destroy |
| Redis | ElastiCache 7.1, `cache.t4g.micro`, one node, TLS in transit with an auth token |
| Identity | Cognito Essentials pool, SPA client, hosted domain, one group per role |
| Claims | A pre-token Lambda, held in Terraform so a pool rebuild cannot drop it |
| AI | An IAM user and access key scoped to Bedrock |

Redis has no snapshots, deliberately. It holds cache and queue state, so there is nothing in
it worth restoring.

The module ships the small shape and takes no `size` variable yet. The
[size table](./deployment-options.md) describes where medium and large land when it does.

Postgres connections are direct rather than pooled. The smallest RDS instance allows well
over a hundred, so the [connection budget](./data.md) has ample headroom.

## What the POC costs to run

Estimates at on-demand list prices in a US region, mid-2026. Round numbers, for budgeting
rather than billing.

| | Monthly, about |
| --- | --- |
| EC2 `t3.xlarge` | $120 |
| Application Load Balancer | $20 |
| RDS `db.t4g.small` with 20 GB | $26 |
| ElastiCache `cache.t4g.micro` | $12 |
| Storage, public IPv4, DNS, transfer | $15 |
| **Total** | **about $195 a month** |

Cognito is free at POC scale, and the certificate costs nothing. **Model usage is not in
this number**: Bedrock bills per token, so the AI cost follows what your Agents actually do
rather than the infrastructure. The instance is the bulk of the bill, and a POC that stops
it outside working hours roughly halves that line.

### Tokens, and how many users a POC can take

The table above is the infrastructure alone. Tokens are the other bill, and they scale with
people rather than with servers: every Agent turn spends model tokens, so this line follows
how many users you let in and how hard they work the Agents.

Arithmetic you can redo with your own numbers: a pilot user who runs twenty Agent turns a
day, at a few thousand tokens a turn, spends one to two million tokens a month. Fifty pilot
users is then fifty to a hundred million tokens a month, which at mid-2026 prices is tens to
a few hundred dollars. Model choice moves that by an order of magnitude; user count only
multiplies it.

As for the box itself: plan on **a few hundred signed-in users and tens of simultaneous
Agent runs**. That is a pilot, not production. And in practice the first ceiling is not the
machine but your AI provider's rate limits, tokens per minute on your Bedrock or OpenAI account, which caps simultaneous Agent work long before the CPU does.
[Deployment Options](./deployment-options.md) has the sizes above this one.

## One load balancer, host-routed

The Application Load Balancer is the only thing facing the internet. Its own security group
takes 80 and 443 from the world, 80 redirects to 443, and the application security group
accepts 4105 and 3001 from that load balancer and nothing else. The instance is not reachable
directly.

**One door serves both hostnames**, which is the thing DigitalOcean cannot do. `api.<domain>`
forwards to the engine on 4105 by default. Turning on `canvas_public` adds a listener rule
for `unoverse.<domain>` to Canvas on 3001, and adds that name to the certificate. On
[DigitalOcean](./digitalocean.md) the same outcome costs a second load balancer, because its
load balancers cannot route on the hostname.

**The idle timeout is 3600 seconds**, set deliberately. Streaming and the websocket are
long-lived, and the ALB default of 60 seconds severs them.

**An unknown hostname falls through to the platform** rather than being rejected at the
edge. That is safe because the authentication gate is in the application, so the load
balancer is never load bearing for security.

The certificate is ACM with DNS validation. If your zone is in Route 53 the module creates
the validation records and the A records itself. Otherwise it prints the records for you to
create once.

## Still single availability zone

One instance, one database with failover off, one cache node. That is the right shape for a
POC and the wrong shape for production. Moving is a variable rather than a redesign, and the
picture above does not change: what alters is what sits behind the load balancer, which is
where the multiple-instance work will land.

---

**Next**: [DigitalOcean](./digitalocean.md)
