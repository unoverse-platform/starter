---
sidebarTitle: "Test Connectivity"
title: "Runbook: Test Connectivity"
---

Verify all services are running and accessible.

## Overview

This runbook validates:

- Docker is running
- All containers are healthy
- Internal ports are open
- Health endpoints respond
- External access works (once DNS points api.&lt;domain&gt; at the load balancer)

## Prerequisites

- [ ] Core services deployed ([01-core.md](./01-core.md))
- [ ] Database configured ([02-database.md](./02-database.md))

## Steps

### 1. Run Connectivity Test

```bash
unoverse deploy test
```

### 2. Manual Verification (Optional)

```bash
# SSH to VM
ssh root@<VM_IP>

# Check containers
docker compose ps

# Check logs
docker compose logs --tail=50 unoverse
docker compose logs --tail=50 canvas
```

## Expected Output

```
PLATFORM HEALTH CHECK
============================================
Host: gravity-prod (<YOUR_VM_IP>)

── Infrastructure ──
Docker: OK

Containers:
  gravity-unoverse running Up 2 hours
  gravity-memory running Up 2 hours
  gravity-canvas running Up 2 hours
  gravity-umap running Up 2 hours

Restarting: NONE

── Ports ──
  - Canvas (3001): OK
  - Unoverse (4105): OK
  - Engine (4101, served by unoverse): OK
  - Memory (4104): OK

── External Dependencies ──
Redis: REACHABLE
  host=your-redis.db.ondigitalocean.com port=25061
Database: REACHABLE
  host=your-db.db.ondigitalocean.com port=25060

── Health Endpoints ──
  - Unoverse: OK
  - Workflow engine: OK
  - Memory: OK

── API Endpoints (read) ──
  - GET /api/workflows: HTTP 200
  - GET /api/nodes: HTTP 200
  - GET /api/prompt-blocks: HTTP 200

── API Write Test ──
  - POST /api/workflows: HTTP 201

── Plugins & Packages ──
Unoverse: nodes=97
Packages: design-system openai flow skills ...
packages_mounted=16

── Recent Errors in Logs ──
No recent errors

── Public Domain ──
Domain: yourdomain.com
  - https://api.yourdomain.com/health: HTTP 200
============================================
```

> **Note:** The domain check reads `DOMAIN=` from `/opt/gravity/.env`. If set to `example.com` or empty, domain checks are skipped.

## Service Health Endpoints

| Service      | URL                            | Expected |
| ------------ | ------------------------------ | -------- |
| Unoverse     | `http://localhost:4105/health` | 200 OK   |
| Workflow engine (in-process on unoverse) | `http://localhost:4101/health` | 200 OK   |
| Memory       | `http://localhost:4104/health` | 200 OK   |
| UMAP         | `http://localhost:5001/health` | 200 OK   |

> Unoverse serves `/health` on its public port `:4105` (host-reachable); it has no `/ready` endpoint. Its internal runtime port `:4106` is never published, so there is nothing to health-check from the host. `:4101` is the workflow engine surface — it runs in-process inside the unoverse container.

## Troubleshooting

| Issue                     | Cause               | Fix                                         |
| ------------------------- | ------------------- | ------------------------------------------- |
| Container not running     | Crashed on startup  | Check logs: `docker compose logs <service>` |
| Health check failed       | Missing env vars    | Verify `.env` at `/opt/gravity/.env`        |
| Port closed               | Service not started | Restart: `docker compose restart <service>` |
| Database connection error | Wrong DATABASE_URL  | Re-run [02-database.md](./02-database.md)   |

## Quick Commands

```bash
# Restart all services
docker compose restart

# Restart specific service
./unoverse build

# View logs
docker compose logs -f unoverse

# Check resource usage
docker stats
```

## Local Development Verification

Locally, the whole checklist is one command:

```bash
./unoverse check
```

It verifies containers, health endpoints (`:4105`, `:4101`, `:4104`, `:5001`), the loaded node catalog, component bundles, and **Canvas** reachability — the same checks `unoverse deploy test` runs against a server. If something is off, `./unoverse doctor` diagnoses the environment.

## Next Steps

If all tests pass, your deployment is complete!

For ongoing operations:

- **Upgrades:** `unoverse deploy` (pull latest images + restart)
- **Backups:** `cd ansible && ansible-playbook playbooks/backup.yml`
- **Rollback:** `cd ansible && ansible-playbook playbooks/rollback.yml`
