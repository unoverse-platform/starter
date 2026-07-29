---
sidebarTitle: "Who Can Run It"
title: "Who Can Run It"
---

A credential is your node's key to a service. This page is the other question: who is
allowed to make your node run at all.

Two directions, two keys, and it is worth keeping them apart from the start:

| In | Key | Question |
| --- | --- | --- |
| `api/run.yaml` | `credential` | how does my node prove itself to **the API**? |
| `node.yaml` | `auth` | may **this caller** run my node? |

Outbound and inbound. This page is the inbound one.

## Two people answer it

You are one of them. The other is whoever builds a workflow with your node in it, and they
know something you cannot.

**You set the floor, in `node.yaml`.** It is compulsory on every node. Not because most need
protecting (most do not), but because a node that says nothing is indistinguishable from a
node nobody thought about, and a reviewer cannot tell those apart.

There are three shapes. Each one is described first, then written.

**1. Adds nothing, and this is almost every node.** The run arrived through a trigger, the
trigger already decided who was let in, and your node runs as that person. It does **not**
mean public.

```yaml node.yaml
auth:
  required: false
```

**2. Any signed-in caller.** Use it when the node is privileged however it is wired up, so
an anonymous visitor must never reach it.

```yaml node.yaml
auth:
  required: true
```

**3. One specific claim.** Only for a role the **platform** defines, so it means the same
thing in every universe. Rare, and the next section is why.

```yaml node.yaml
auth:
  required: true
  role: marketplace:publish
```

**Whichever of the three you write, three rules hold:**

- `required` is always written out. Leaving it off is a lint error rather than a default,
  because a node saying nothing is what this block exists to stop.
- A role with `required: false` is a lint error. A role lives on a token, so demanding one
  while waiving the token can never be satisfied. It would read as protected on the
  acceptance screen and admit everyone at run time.
- A manifest that reaches the executor with no `auth` block at all is treated as
  `required: true`. The platform's default is deny.

**They set the rest, on the Canvas.** Every node carries the same two settings:

| Setting | |
| --- | --- |
| **Require sign-in** | A toggle, off by default |
| **Require role** | A text box, shown only once the toggle is on |

Per box. The same node type legitimately faces staff on one workflow and customers on
another, and only the person building that workflow knows which.

## Why a role usually belongs to them, not you

`finance:approve` is a claim **one deployment's identity provider mints**. If your node is
published and someone installs it in their universe, you have no idea what roles their
Auth0 or Cognito issues. Name one in your manifest and it fails for everybody else.

So: name a role in `node.yaml` only for a claim the *platform* defines (`workflow:author`,
`marketplace:publish`). Anything about someone's business belongs in the config field, set
by the person who knows their own role names.

## The whole rule

| Set by | Where | What it means |
| --- | --- | --- |
| You | `auth.required: false` | Adds nothing. Runs for whoever the trigger admitted. The default. |
| You | `auth.required: true` | Signed-in caller, whatever the trigger allowed |
| You | `auth.role` | A platform-wide claim. Implies `required: true` |
| Builder | `Require sign-in` toggle | Signed-in caller, for this box only |
| Builder | `Require role` | A claim in *their* vocabulary, for this box only |

**The stricter of the two always wins, and neither can loosen the other.** Turning the
builder's toggle off does not unlock a node you marked `required: true`. If both name a
role, the caller needs both.

There is no setting anywhere that widens a run. `role` with `required: false` in a manifest
is a lint error rather than a promise that could never be kept.

Letting anonymous visitors in at all is a decision about a *workflow*, not a node, so it is
a separate toggle on the trigger.

## Roles read as noun then verb

`finance:approve`. `payments:refund`. `crm:write`.

Two words say what the role is actually for. `admin` does not, and two packages that both
invent one never mean the same thing by it.

**One role per node.** If a node seems to need two, it is usually two nodes.

The claim is matched against the caller's `roles` **and** `permissions`. Both are `noun:verb`
claims off the same token, so you do not have to know which list your identity provider put
a string in.

## What you actually write

`node.yaml` gets the floor. `config.yaml` gets the two builder fields, and they are the same
in every node, so copy them:

```yaml config.yaml
configSchema:
  type: object
  properties:
    authRequired:
      type: boolean
      title: Require sign-in
      description: >-
        Only a signed-in caller may run this step. Leave off
        and it runs for whoever the workflow's trigger
        admitted, which is the usual answer.
      default: false
      "ui:widget": toggle
    authRole:
      type: string
      title: Require role
      description: >-
        A claim the caller's account must carry, as noun:verb
        (finance:approve, payments:refund). Leave blank to
        require only that they are signed in.
      default: ""
      "ui:dependencies": { authRequired: true }

ui:order: [model, prompt, authRequired, authRole]
```

Put both in `ui:order` too, at the end, after your own fields. They are settings about
access rather than about the job, so they belong last.

Lint checks all of it: both fields present, the right types, the toggle rendering as a
toggle, the role box hidden until the toggle is on, and both defaulting to off. A node that
gated by default would break every workflow already using it.

## Where it is enforced

**On a trigger**, at the door, before anything runs. Whether an anonymous visitor gets
through that door is the Canvas toggle above.

**Anywhere else**, as the node starts, against the identity the run already carries, and
before any call is built. A refused run costs no vendor request and has no side effect.

That includes a node reached over a **service edge**. It is the easy one to forget: such a
node fires no connectors of its own, so it reads as an internal detail of whatever called
it. It still runs your calls with your credentials, so it is gated like anything else.

## A missing role is loud

The node fails and names the claim it wanted. It does not quietly skip its work, and it
does not carry on with a blank where the person should have been.

That is worth choosing on purpose. A node that no-ops when identity is absent looks fine in
testing and does nothing in production, and nobody finds out for a week.

## Identity in your templates

An authenticated run gives your manifest the person:

```yaml api/run.yaml
body:
  requestedBy: "{{ user.email }}"
```

`user.id`, `user.email` and `user.name` are available.

The token itself never reaches your manifest. You get to know who the caller is. You do not
get to hold the thing that proves it, because a manifest that could read it could also send
it somewhere.

## What a reviewer sees

Requirements appear on the acceptance screen next to the hosts your node calls and the
credentials it needs. A node that starts demanding a role, or starts reading identity, is a
change worth seeing before it goes live.

---

**Next**: [Config Schema](./06-config-schema.md)
