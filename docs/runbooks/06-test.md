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

Run these checks after `unoverse dev` or `unoverse update` to verify everything is working.

### Quick Check (copy-paste this block)

```bash
echo "=== Gravity Platform Health Check ==="
echo ""

# 1. Services running
echo "1. Services"
for svc in unoverse canvas umap memory; do
  status=$(docker compose ps --format '{{.Status}}' $svc 2>/dev/null | head -1)
  if echo "$status" | grep -q "Up"; then
    echo "   ✓ $svc — $status"
  else
    echo "   ✗ $svc — NOT RUNNING"
  fi
done
echo ""

# 2. Health endpoints
echo "2. Health Endpoints"
for url in http://localhost:4105/health http://localhost:4101/health http://localhost:4104/health http://localhost:5001/health; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
  name=$(echo "$url" | grep -oE '[0-9]+' | head -1)
  if [ "$code" = "200" ]; then
    echo "   ✓ :$name — 200 OK"
  else
    echo "   ✗ :$name — $code"
  fi
done
echo ""

# 3. Packages built
echo "3. Packages (dist/index.js)"
built=0; total=0
for pkg in packages/*/; do
  [ -f "$pkg/package.json" ] || continue
  name=$(basename "$pkg")
  # Skip non-plugin packages
  case "$name" in design-system|gravity-client|plugin-base|skills|prompt-blocks) continue;; esac
  total=$((total + 1))
  if [ -f "$pkg/dist/index.js" ]; then
    built=$((built + 1))
  else
    echo "   ✗ $name — missing dist/index.js"
  fi
done
echo "   ✓ $built/$total packages built"
echo ""

# 4. Unoverse node catalog
# The internal :4106 runtime is Docker-network-only and :4105 /plugins is
# JWT-gated, so count nodes from INSIDE the container.
echo "4. Unoverse Nodes"
node_count=$(docker compose exec -T unoverse node -e \
  "fetch('http://127.0.0.1:4106/nodes').then(r=>r.json()).then(d=>console.log((d.nodes||[]).length)).catch(()=>console.log(0))" 2>/dev/null | tr -d ' \r')
echo "   Nodes registered: $node_count"
echo ""

# 5. Component bundles served
echo "5. Component Bundles (unoverse → Canvas)"
for comp in StreamingText.js Card.js ChatInput.js; do
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:4105/components/$comp" 2>/dev/null)
  if [ "$code" = "200" ]; then
    echo "   ✓ /components/$comp — 200"
  else
    echo "   ✗ /components/$comp — $code"
  fi
done
echo ""

# 6. Canvas accessible
echo "6. Canvas UI"
code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3001 2>/dev/null)
if [ "$code" = "200" ]; then
  echo "   ✓ http://localhost:3001 — 200 OK"
else
  echo "   ✗ http://localhost:3001 — $code"
fi
echo ""
echo "=== Done ==="
```

### Expected Output (all passing)

```
=== Gravity Platform Health Check ===

1. Services
   ✓ unoverse — Up 2 minutes
   ✓ canvas — Up 2 minutes
   ✓ umap — Up 2 minutes
   ✓ memory — Up 2 minutes

2. Health Endpoints
   ✓ :4105 — 200 OK
   ✓ :4101 — 200 OK
   ✓ :4104 — 200 OK
   ✓ :5001 — 200 OK

3. Packages (dist/index.js)
   ✓ 12/12 packages built

4. Unoverse Nodes
   Nodes registered: 45

5. Component Bundles (unoverse → Canvas)
   ✓ /components/StreamingText.js — 200
   ✓ /components/Card.js — 200
   ✓ /components/ChatInput.js — 200

6. Canvas UI
   ✓ http://localhost:3001 — 200 OK

=== Done ===
```

### Troubleshooting Failures

| Check                  | Failure                            | Fix                                                       |
| ---------------------- | ---------------------------------- | --------------------------------------------------------- |
| Services not running   | Container crashed                  | `docker compose logs <service>` then `unoverse update`     |
| Health endpoint failed | Missing `.env` vars                | Check `.env` has `REDIS_HOST`, `DATABASE_URL`, auth vars  |
| Packages not built     | No `dist/` directory               | `unoverse update` (builds all packages)                    |
| Nodes registered: 0    | unoverse didn't load packages      | Check `docker compose logs unoverse`, then re-run `unoverse update` |
| Component bundles 404  | Unoverse can't find design-system  | Verify the `packages/` mount (`/app/host_packages`) contains `design-system/components/` |
| **Canvas** 404             | Container not started              | `docker compose up -d canvas`                             |

## Next Steps

If all tests pass, your deployment is complete!

For ongoing operations:

- **Upgrades:** `ansible-playbook playbooks/install.yml` (re-run to pull latest images)
- **Backups:** `ansible-playbook playbooks/backup.yml`
- **Rollback:** `ansible-playbook playbooks/rollback.yml`
