---
sidebarTitle: "Deployment"
title: "Deployment"
---

Deploy Unoverse to production VMs.

## Overview

Production deployment uses `unoverse deploy` which reads your `.env.production` file and runs Ansible playbooks to install and configure services on your VM.

## Prerequisites

- SSH access to target VM
- Ansible installed locally (`pip install ansible`)
- DOCR token for pulling images
- PostgreSQL instance provisioned (customer-managed)

## Quick Deploy (Single VM)

```bash
# 1. Render the production environment from your Terraform ground
cd infra/digitalocean && terraform apply     # or infra/aws
terraform output -raw env_production > ../../.env.production
cd ../..

# 2. Deploy core services
unoverse deploy

# 3. Set up database
unoverse deploy db

# 4. Deploy AI model (optional)
unoverse deploy umap

# 5. TLS with Caddy (optional)
unoverse deploy caddy

# 6. Verify
unoverse deploy test
```

## What `.env.production` Contains

Same format as `.env` (local dev), plus:

```bash
# Deploy target (where to SSH)
DEPLOY_HOST=134.209.x.x
DEPLOY_USER=root          # Azure: azureuser, AWS: ubuntu

# Production Redis (instead of local)
REDIS_HOST=your-managed-redis.com
REDIS_PORT=25061
REDIS_PASSWORD=your-password
REDIS_TLS=true

# Domain (enables HTTPS via Caddy)
DOMAIN=yourdomain.com
```

Everything else (DATABASE_URL, Auth0, OpenAI) stays the same as your local `.env`.

## Runbooks

For detailed step-by-step guides, see the [Runbooks](../runbooks/overview.md):

| Runbook                                             | Description                    |
| --------------------------------------------------- | ------------------------------ |
| [01-core](../runbooks/01-core.md)                   | Deploy core app services       |
| [02-database](../runbooks/02-database.md)           | Set up database tables         |
| [03-ai-model](../runbooks/03-ai-model.md)           | Deploy UMAP AI service         |
| [04-harden](../runbooks/04-harden.md)               | Security hardening             |
| [05-caddy](../runbooks/05-caddy.md)                 | TLS + reverse proxy            |
| [06-test](../runbooks/06-test.md)                   | Verify connectivity and health |
| [07-observability](../runbooks/07-observability.md) | Dozzle log viewer (POC only)   |
| [08-deploy-packages](../runbooks/08-deploy-packages.md) | Deploy packages to server  |

## Deploying Custom Code

After deploying the platform, push your custom nodes and components:

```bash
unoverse deploy packages
```

## Advanced: Multi-VM Enterprise

For multi-VM setups (separate app VMs + ML VMs), use `ansible/inventory/production.yml` directly. See `ansible/inventory/production.yml.example` for the template.

## ✅ Challenge Complete

Your platform is deployed to production! Proceed to [Challenge 9: Update Unoverse](./09-update-unoverse.md).
