---
sidebarTitle: "Deployment"
title: "Deployment"
---

Deploy Unoverse to production VMs.

## Overview

Production deployment uses `unoverse deploy`, which reads your ground's rendered configuration and runs Ansible playbooks to install and configure services on your VM.

## Prerequisites

- SSH access to target VM
- Ansible installed locally (`pip install ansible`)
- DOCR token for pulling images
- PostgreSQL instance provisioned (customer-managed)

## Quick Deploy (Single VM)

```bash
# 1. Provision your ground
./unoverse ground                            # prefills terraform.tfvars from your cloud CLI
cd infra/digitalocean && terraform apply     # or infra/aws
cd ../..

# 2. First-time setup: install + database + verify
unoverse deploy init
```

After that, every deploy is one command:

```bash
unoverse deploy
```

## What the Rendered Configuration Contains

You never write it (Terraform renders it; deploy places it on the server), but for the curious it is the same format as `.env`, plus:

```bash
# Deploy target (where to SSH)
DEPLOY_HOST=134.209.x.x
DEPLOY_USER=root          # Azure: azureuser, AWS: ubuntu

# Production Redis (instead of local)
REDIS_HOST=your-managed-redis.com
REDIS_PORT=25061
REDIS_PASSWORD=your-password
REDIS_TLS=true

# Domain (TLS terminates at your ground's load balancer)
DOMAIN=yourdomain.com
```

Everything else (DATABASE_URL, Auth0, OpenAI) stays the same as your local `.env`.

## Runbooks

For detailed step-by-step guides, see the [Runbooks](../runbooks/overview.md):

| Runbook                                             | Description                    |
| --------------------------------------------------- | ------------------------------ |
| [01-core](../runbooks/01-core.md)                   | Deploy core app services       |
| [02-database](../runbooks/02-database.md)           | Set up database tables         |
| [04-harden](../runbooks/04-harden.md)               | Security hardening             |
| [06-test](../runbooks/06-test.md)                   | Verify connectivity and health |

## Deploying Your Own Work

Content does not ride `unoverse deploy` (that moves platform images only). Your work reaches the server three ways:

- **The carve-out** (nodes, `rx/`, prompts in your repo): `unoverse update` on the server pulls your git repo and rebuilds.
- **Marketplace items**: installed per item from Studio's Marketplace tab; database-driven, no restart.
- **Studio publish**: publishes straight to the universe over the API (publish key via `unoverse key`).

## Start on a Test Domain, Swap Later

The domain is a Terraform input, not a commitment. Deploy today under any domain you control (even a delegated subdomain like `acme-poc.yourcompany.com`) and move to the real one when it exists. Nothing in the universe's data references the hostname.

The swap:

1. Change `domain` in `terraform.tfvars`, then `terraform apply`. A new certificate and DNS records are created; the VM, database, Redis, and everything in them are untouched.
2. Redeploy: delete `.env.production` at the repo root and run `unoverse deploy` — it re-renders from the applied ground.
3. Update your IdP: add the new origins and callback URLs in Auth0 or Cognito. This is the only manual step, and the one people forget.

Swap before handing URLs to real users: browser sessions and shared links reference the old hostname, and that is the entire cost of the move.

Working with no domain at all also gets you surprisingly far: `http://IP:3001` and `http://IP:4105` prove a deployment is healthy. You just cannot log in until HTTPS exists, because OIDC providers refuse plain-IP redirect flows.

## ✅ Challenge Complete

Your platform is deployed to production! Proceed to [Challenge 9: Update Unoverse](./09-update-unoverse.md).
