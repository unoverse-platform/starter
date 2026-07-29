---
sidebarTitle: "Environments"
title: "Environments and Promotion"
mode: "wide"
---

Development, UAT and production are three universes. Each is its own apply of the same
Terraform, with its own variables and its own identity provider client.

That is the whole story for infrastructure, and it is what the contract exists for.

## Promotion is three separate movements

Treating it as one button is how environments drift. It is three, and they move at different
speeds.

```mermaid
%%{init: {"theme":"base","themeVariables":{"fontFamily":"Inter, ui-sans-serif, system-ui","fontSize":"14px","primaryColor":"#EFECFE","primaryBorderColor":"#6D5DF6","primaryTextColor":"#1B1C2A","secondaryColor":"#F4F4F7","tertiaryColor":"#F4F4F7","lineColor":"#8E94A4","clusterBkg":"#FBFBFD","clusterBorder":"#E4E5EC","edgeLabelBackground":"#FFFFFF","nodeBorder":"#6D5DF6"}}}%%
flowchart LR
  subgraph U ["UAT"]
    direction TB
    U1["Infrastructure"]
    U2["Platform version"]
    U3["Authored assets"]
  end

  subgraph P ["Production"]
    direction TB
    P1["Infrastructure"]
    P2["Platform version"]
    P3["Authored assets"]
  end

  U1 -.->|"own apply,<br/>own variables"| P1
  U2 -->|"pinned image tag"| P2
  U3 -->|"publish"| P3
```

**Infrastructure** does not move. Each environment is provisioned independently from the
same module, so production is not a copy of UAT, it is another instance of the same
definition.

**The platform version** moves as an image tag. UAT runs a tag first and production follows
it. This requires pinned tags rather than a floating latest, so that "production runs what
UAT tested" is a fact rather than a hope.

**Authored assets** move by publishing. Components, templates, skills and prompt blocks are
rows in a universe's database, and promoting one means publishing it to the next universe.
That is the same mechanism a developer uses from **Studio**, pointed at a different address.

## What never moves

Data stays where it is. Conversations, memory, traces and credentials are properties of an
environment, not of a release.

Secrets are re-entered in production. They are never copied forward, because a secret that
has been in a test environment is a test secret.

## A gap worth knowing about

**Workflows have no promotion lane.** Components, skills and nodes are all publishable items
with a version history. Workflows are not, so moving one from UAT to production today means
rebuilding it on the production canvas.

This is a known limitation rather than a design position, and closing it is required work
for real multi-environment operation. Plan around it if your process depends on promoting
workflows rather than rebuilding them.

## Day-two operations

Once a universe is running, the routine work is small and each piece has a runbook.

| | |
| --- | --- |
| Platform upgrades | Pull new image tags and restart |
| Database migrations | Run against a live universe, forward only |
| Rolling back | Images roll back. Migrations do not, by design |
| Node inventory | Reconcile the database against what is installed |
| Backups | Provider-native, plus the **Spatial ML** models and the credential encryption key |
| Publish keys | Issued on the box, for CI and for first connection |
| Resizing | Change the size variable, apply, redeploy |

Content does not appear in that list, and that is the point. Assets reach a universe by
publishing and nodes install themselves from the record in the database, so neither one
requires a deployment.

---

**Next**: [Runbooks](../runbooks/overview.md)
