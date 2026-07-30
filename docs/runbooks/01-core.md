---
sidebarTitle: "Core Services"
title: "Runbook: Core Services"
---

Deploy the core Gravity Platform services to a VM.

## Services Deployed

| Service          | Port | Description                         |
| ---------------- | ---- | ----------------------------------- |
| **unoverse**     | 4105 | Platform runtime — workflow engine (in-process), node plane, `/api`, native MCP (`/mcp`), data plane |
| **memory**       | 4104 | Evidence-based user memory          |
| **Canvas**       | 3001 | Web UI                              |

> **Unoverse has three listeners.** `:4105` is the public port (JWT-gated: `/api/*`, MCP defs, workbench, `/plugins` management, `/health`). `:4106` is the internal node runtime (`/execute`, `/nodes`, `/skills`, `/health`) — it lives on the Docker network only and is deliberately never published or proxied; network isolation is the trust boundary. `:4101` is the workflow engine surface (internal; other containers reach it as `http://unoverse:4101`).

## VM Requirements

Sized by `size` in terraform.tfvars (`small` | `medium` | `large`). All sizes are single-VM: the size scales the box and the stores, never the topology.

## Prerequisites

- [ ] Terraform ground applied (VM, load balancer + TLS, firewall, Postgres, Redis — see the [overview](./overview.md))
- [ ] DOCR token in your terraform.tfvars (from your Unoverse admin)

## Steps

### 1. Configure Production Environment

There is nothing to write. Terraform renders `.env.production`, complete, from your `terraform.tfvars`, and `unoverse deploy` renders it from the applied ground automatically if the file is missing:

```bash
./unoverse ground                            # prefills terraform.tfvars from your cloud CLI
cd infra/digitalocean && terraform apply     # or infra/aws
cd ../..
```

The rendered file contains:

```bash
# Deploy target
DEPLOY_HOST=<YOUR_VM_IP>
DEPLOY_USER=root              # Azure: azureuser, AWS: ubuntu, GCP: debian

# DOCR - DigitalOcean Container Registry
DOCR_TOKEN=dop_v1_your_token_here

# Database and Redis
DATABASE_URL=postgresql://user:pass@host:5432/gravity
REDIS_HOST=your-redis-host
REDIS_PORT=25061              # DO Managed Redis uses 25061; local Redis uses 6379
REDIS_PASSWORD=your-redis-password
REDIS_TLS=true

# Domain (for HTTPS)
DOMAIN=yourdomain.com
```

> **Note:** `.env.production` is gitignored — it will not be overwritten when you run `unoverse update`. Only the `.example` file is tracked in git.

> **Do not set `ansible_become_password` or `ansible_become_flags`** for cloud VMs. Their default users already have passwordless sudo configured by the cloud provider.

### 2. Run Core Platform Installation

```bash
unoverse deploy init
```

One command, four phases: installs Docker, pulls DOCR images, and starts every service (unoverse, memory, **Canvas**, umap, Dozzle); sets up the database; applies security hardening; and verifies connectivity. The CLI generates a temporary Ansible inventory from `.env.production` on every run, so there is no inventory file to maintain.

Every deploy after the first is just:

```bash
unoverse deploy
```

### 3. Verify (re-run any time)

```bash
unoverse deploy test
```

## Expected Output

```
GRAVITY PLATFORM DEPLOYED
============================================
Host: gravity-prod (<YOUR_VM_IP>)

Service Health:
  - Unoverse:      OK
  - Memory:        OK
  - Canvas:        OK

Access URLs:
  - Canvas:  http://<YOUR_VM_IP>:3001
  - API:     http://<YOUR_VM_IP>:4105

Internal Only (SSH tunnel required):
  - Memory:  http://localhost:4104/dashboard
```

> **Memory dashboard is internal-only.** Access via SSH tunnel: `ssh -L 4104:localhost:4104 root@<VM_IP>` then open `http://localhost:4104/dashboard`. It is never exposed through the load balancer.

## Troubleshooting

| Issue               | Cause            | Fix                                            |
| ------------------- | ---------------- | ---------------------------------------------- |
| DOCR login failed   | Invalid token    | Get a new DOCR token from your Gravity admin   |
| Service unhealthy   | Missing env vars | Check `.env.production` and `/opt/gravity/.env` on VM |
| Port already in use | Previous install | Run `docker compose down` first                |
| `Timeout (12s) waiting for privilege escalation prompt` | `ansible_become_password` set to empty string in inventory | Remove `ansible_become_password` and `ansible_become_flags` from inventory entirely — cloud default users (azureuser, ubuntu) have passwordless sudo and need no password |

## Next Steps

- [02-database.md](./02-database.md) - Configure database connection
- Your own nodes, design, and prompts arrive via `unoverse update`, the Marketplace, or Studio publish (never via deploy)
