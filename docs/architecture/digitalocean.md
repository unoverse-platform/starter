---
sidebarTitle: "DigitalOcean"
title: "unoverse on DigitalOcean"
mode: "wide"
---

The first ground built end to end, and the one to copy. It is the smallest amount of
infrastructure that still satisfies an enterprise review.

<div className="figure-wide">
<Frame caption="Everything Terraform creates in your DigitalOcean project. Click to enlarge.">
  <img src="/images/architecture-digitalocean.svg" alt="Everything Terraform creates in your DigitalOcean project. Click to enlarge." />
</Frame>
</div>

<div className="fig-notes">
<div>
<p className="fig-title">Exposure</p>
<ul>
<li><span className="zone" style={{ background: "#d97706" }} /><span>Reached from the internet</span></li>
<li><span className="zone" style={{ background: "#7c3aed" }} /><span>Operator address only</span></li>
<li><span className="zone" style={{ background: "#0f766e" }} /><span>Published on the droplet, blocked by the firewall</span></li>
</ul>
</div>
<div>
<p className="fig-title">The paths</p>
<ul>
<li><span className="num">1</span><span>A client reaches the load balancer at api.&lt;domain&gt; on 443. It terminates TLS with a managed certificate and forwards to the engine on 4105, which the firewall opens to that load balancer alone.</span></li>
<li><span className="num">2</span><span>An operator reaches Canvas at canvas.&lt;domain&gt;:3001 over HTTPS, the same load balancer and certificate on a second port. SSH on 22, the log viewer on 8080 and Canvas direct on 3001 stay open to your address, and are the only route when canvas_public is off.</span></li>
<li><span className="num">3</span><span>The droplet reaches Postgres through its transaction pool and Redis over TLS. Each database firewall admits the droplet and nothing else.</span></li>
<li><span className="num">4</span><span>Tokens are verified against the OIDC issuer you bring. DigitalOcean universes have no identity provider of their own.</span></li>
<li><span className="num">5</span><span>Nodes call out on 443, only to hosts their own package declares.</span></li>
</ul>
</div>
</div>

<Note>
**Why the Canvas URL carries a port.** DigitalOcean load balancers cannot route on the hostname, so a clean second hostname would cost a second load balancer. The POC takes the port in the URL instead: one load balancer, and Canvas at `https://canvas.<domain>:3001`: the hostname is a SAN on the same certificate and an A record to the same load balancer, so only the port cannot be dropped. On [AWS](./aws.md) the Application Load Balancer host-routes, so the clean hostname comes free there. Decided 2026-07-29, and the asymmetry between the two grounds is accepted: it is DigitalOcean's product limitation, not a design choice.
</Note>

## What Terraform creates

| | |
| --- | --- |
| Compute | A droplet, wrapped in a cloud firewall |
| Entry point | A load balancer with a managed Let's Encrypt certificate, and optionally the DNS record |
| Data | Managed Postgres with its transaction pool, managed Redis, and a database firewall for each |
| Secrets | A generated credential encryption key |

Identity is not on that list. DigitalOcean universes bring their own OIDC issuer, which today
means an existing Auth0 tenant.

## What the POC costs to run

Estimates at list prices, mid-2026. Round numbers, for budgeting rather than billing.

| | Monthly, about |
| --- | --- |
| Droplet, 4 vCPU / 16 GB | $100 |
| Managed Postgres, smallest tier | $15 |
| Managed Redis, smallest tier | $15 |
| Load balancer, small | $12 |
| **Total** | **about $140 a month** |

`canvas_public` adds nothing to this: Canvas rides the same load balancer. Bandwidth is
included at POC traffic levels, and the certificates are free. **Model usage is not in this
number**: OpenAI and the other providers bill per call, so the AI cost follows what your
Agents actually do rather than the infrastructure.

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
machine but your AI provider's rate limits, tokens per minute on your OpenAI account, which caps simultaneous Agent work long before the CPU does.
[Deployment Options](./deployment-options.md) has the sizes above this one.

## The firewall rules, in full

| Port | Source |
| --- | --- |
| 4105 | The load balancer, and only the load balancer |
| 3001 | Your address. Plus the load balancer, when `canvas_public` is on |
| 22 | Your address |
| 8080 | Your address |

**Canvas has two possible doors, and one of them is optional.** By default it is reached
direct on 3001 from your address, in the same trust ring as SSH and the log viewer. That is
the contract default and the posture an enterprise deployment should keep.

Turning on `canvas_public` adds a second forwarding rule to the same load balancer:
`https://canvas.<domain>:3001`, terminating TLS with the same certificate (the hostname is a
SAN on it) and forwarding to Canvas. The firewall then admits the load balancer on 3001 as well. It does not open 3001 to
the internet: direct access to the droplet stays restricted to your address either way, so
the public route exists only through the load balancer.

**The shipped `terraform.tfvars.example` turns it on**, because this ground's first job is
the POC box and a POC usually wants Canvas reachable in a browser. The variable itself
defaults to `false`. So an operator following the example gets the second rule, and anyone
applying the module without it does not. The `canvas_url` output prints the exact URL, and
it has to be added to your identity provider's allowed origins.

## Two facts found while building it

**The idle timeout caps at 600 seconds.** The platform holds long-lived connections, and
DigitalOcean will not hold one quiet for longer than ten minutes. The Terraform sets the
maximum, and a client that goes quiet must reconnect cleanly. That belongs in your acceptance
test rather than in a footnote.

**Postgres is always pooled.** The smallest managed database allows around nineteen usable
connections, and the platform's pools would ask for roughly thirty-two if each were tuned
alone. The managed transaction pooler turns those nineteen into hundreds of client
connections. [Data and State](./data.md) has the budget and the two rules that come with
pooling.

## Bringing your own Postgres

Two ways, both first-class. Give Terraform the name of an existing managed cluster and it
adds this universe's database, user, pool and firewall rule to it. Or give it a URL and it
uses that verbatim. [Data and State](./data.md) covers what you take on.

## Sizing

`size` is `small`, `medium` or `large`, and it moves the droplet, both databases, the backup
window and the connection budget together. Change it, apply, redeploy.

---

**Next**: [Azure](./azure.md)
