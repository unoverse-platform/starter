---
sidebarTitle: "Overview"
title: "Runbooks"
---

Modular runbooks for deploying and managing Gravity Platform VMs.

---

## Infrastructure Requirements

### VM Specifications

| VM Role    | Cores | RAM   | Storage    | Count             | Services                                                   |
| ---------- | ----- | ----- | ---------- | ----------------- | ---------------------------------------------------------- |
| **POC**    | 4     | 8 GB  | 100 GB SSD | 1                 | All services                                               |
| **App VM** | 8     | 32 GB | 200 GB SSD | 2 (Active/Active) | unoverse, memory, **Canvas** |
| **ML VM**  | 4     | 16 GB | 100 GB SSD | 1 (Dedicated)     | umap-service                                               |

### External Dependencies

| Component      | Requirement                 | Notes                                                                |
| -------------- | --------------------------- | -------------------------------------------------------------------- |
| **PostgreSQL** | 14+                         | Customer-managed (DO Managed, AWS RDS, or self-hosted)               |
| **Redis**      | 7+                          | Customer-managed (DO Managed Redis, AWS ElastiCache, or self-hosted) |
| **Domain**     | DNS A records               | Point to VM IP or Load Balancer IP                                   |
| **TLS**        | Caddy (auto) or customer LB | Caddy auto-provisions Let's Encrypt certs                            |

### Supported Platforms

- **Cloud:** DigitalOcean, AWS, Azure, GCP
- **On-prem:** VMware, Proxmox, bare metal
- **OS:** Ubuntu 22.04 LTS (recommended), Debian 12

---

## Runbook Modules

| Runbook                                                                                                              | Description                                                                      | Ansible Playbook            |
| -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------------- |
| [01-core](./01-core.md)                                                                                              | Deploy core app services                                                         | `install.yml`               |
| [02-database](./02-database.md)                                                                                      | Set up database tables                                                           | `db-setup.yml`              |
| [03-ai-model](./03-ai-model.md)                                                                                      | Deploy UMAP AI service                                                           | `install-umap.yml`          |
| [04-harden](./04-harden.md)                                                                                          | Security hardening                                                               | `harden.yml`                |
| [05-caddy](./05-caddy.md)                                                                                            | TLS + reverse proxy (optional)                                                   | `install-caddy.yml`         |
| [06-test](./06-test.md)                                                                                              | Verify connectivity and health                                                   | `test-connectivity.yml`     |
| [07-observability](./07-observability.md)                                                                            | Dozzle log viewer (POC only)                                                     | `install-observability.yml` |
| [08-deploy-packages](./08-deploy-packages.md)                                                                        | Deploy customer packages to server                                               | `deploy-packages.yml`       |
| [09-restart-rebuild](./09-restart-rebuild.md)                                                                        | Local restart & rebuild decision table                                           | —                           |
| [10-deploy-design](./10-deploy-design.md)                                                                            | Deploy design (rx/) only: rsync + restart, no build                              | `deploy-design.yml`         |
| [Architecture Diagrams](https://unoverse-platform.github.io/starter/docs/runbooks/architecture-diagrams/index.html) | Interactive system architecture diagrams ([local](./architecture-diagrams/index.html)) | —                           |

---

## VM Deployment Recipes

### POC (Single VM - All Services)

**Simple path (recommended):**

```bash
# 1. Configure .env.production (set DEPLOY_HOST, DEPLOY_USER, Redis, DOMAIN, etc.)
cp .env.production.example .env.production

# 2. Deploy everything
unoverse deploy

# 3. Database tables
unoverse deploy db

# 4. AI model
unoverse deploy umap

# 5. TLS
unoverse deploy caddy

# 6. Security hardening
unoverse deploy harden

# 7. Verify
unoverse deploy test
```

**Manual path (direct Ansible):**

```bash
cd ansible

# 1. Core services (Docker, Node.js, DOCR images)
ansible-playbook -i inventory/production.yml playbooks/install.yml

# 2. Database tables
ansible-playbook -i inventory/production.yml playbooks/db-setup.yml

# 3. Customer packages (rsyncs from local, builds on server)
ansible-playbook -i inventory/production.yml playbooks/deploy-packages.yml

# 4. AI model
ansible-playbook -i inventory/production.yml playbooks/install-umap.yml

# 5. Security hardening
ansible-playbook -i inventory/production.yml playbooks/harden.yml

# 6. TLS (optional - if no external LB)
ansible-playbook -i inventory/production.yml playbooks/install-caddy.yml \
  -e "domain=yourdomain.com" -e "include_umap=true"

# 7. Verify
ansible-playbook -i inventory/production.yml playbooks/test-connectivity.yml
```

### Enterprise App VM

```bash
ansible-playbook -i inventory/production.yml playbooks/install.yml -l app_vms
ansible-playbook -i inventory/production.yml playbooks/db-setup.yml -l app_vms
ansible-playbook -i inventory/production.yml playbooks/deploy-packages.yml -l app_vms
ansible-playbook -i inventory/production.yml playbooks/harden.yml -l app_vms
ansible-playbook -i inventory/production.yml playbooks/test-connectivity.yml -l app_vms
```

### Enterprise ML VM

```bash
ansible-playbook -i inventory/production.yml playbooks/install-umap.yml -l ml_vms
ansible-playbook -i inventory/production.yml playbooks/harden.yml -l ml_vms
```

## Environment Files — Two `.env` Files, Two Purposes

Both files live at the project root:

```
┌──────────────────────────────────────────────────────────────────┐
│  .env  (project root)                                            │
│                                                                  │
│  Purpose: LOCAL DEVELOPMENT                                      │
│  Read by: docker compose (automatically reads root .env)         │
│  Contains: localhost Redis, local DB, no TLS, no DOMAIN          │
│                                                                  │
│  Example values:                                                 │
│    REDIS_HOST=host.docker.internal                               │
│    REDIS_PORT=6379                                               │
│    REDIS_PASSWORD=                                               │
│    REDIS_TLS=false                                               │
│    DATABASE_URL=postgresql://postgres:postgres@localhost:5432/... │
│    # DOMAIN is unset — API_URL points Canvas at localhost:4105   │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  .env.production  (project root)                                 │
│                                                                  │
│  Purpose: PRODUCTION DEPLOYMENT                                  │
│  Read by: unoverse deploy / Ansible                               │
│  Deployed to: /opt/gravity/.env on the server                    │
│  Contains: VM target, real Redis, real DB, TLS enabled, DOMAIN   │
│                                                                  │
│  Example values:                                                 │
│    DEPLOY_HOST=134.209.106.203                                   │
│    DEPLOY_USER=root                                              │
│    REDIS_HOST=your-redis.db.ondigitalocean.com                   │
│    REDIS_PORT=25061                                              │
│    REDIS_PASSWORD=your-password                                  │
│    REDIS_TLS=true                                                │
│    DATABASE_URL=postgresql://user:pass@db-host:25060/defaultdb   │
│    DOMAIN=yourdomain.com                                         │
└──────────────────────────────────────────────────────────────────┘
```

**Key rules:**

- Both files are **gitignored** — they contain secrets and are never committed
- `.env.example` is the template for local dev
- `.env.production.example` is the template for production
- On the server, `unoverse deploy` places `.env.production` at `/opt/gravity/.env` where `docker compose` reads it
- `DEPLOY_HOST` and `DEPLOY_USER` are deployment-only — they tell Ansible where to SSH

**How `DOMAIN` drives **Canvas** URLs:**
When `DOMAIN=yourdomain.com` is set, `docker-compose.yml` automatically derives:

- `VITE_API_URL=https://api.yourdomain.com`
- `VITE_SERVER_WS_URL=wss://api.yourdomain.com`

When `DOMAIN` is unset (local dev), set `API_URL=http://localhost:4105` in `.env` — **Canvas** calls the platform's public listener (unoverse `:4105`) directly.

---

## Prerequisites

- SSH access to target VMs
- Ansible installed locally (`pip install ansible`)
- DOCR token for pulling images
- PostgreSQL instance provisioned (customer-managed)
