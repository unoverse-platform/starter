---
sidebarTitle: "Overview"
title: "Runbooks"
---

Running a universe is three phases. Terraform owns the first, the `unoverse` CLI the second, and these runbooks cover the third:

1. **Provision** — your ground (`infra/digitalocean` or `infra/aws`) creates the VM, load balancer, TLS certificate, firewall, Postgres, and Redis, and renders the complete `.env.production`. `./unoverse ground` prefills its input file from your cloud CLI.
2. **Deploy** — `unoverse deploy init` the first time, `unoverse deploy` after that.
3. **Operate** — database, hardening, health, restarts: the runbooks below.

---

## Provision (Terraform)

```bash
./unoverse ground                            # prefills terraform.tfvars from your cloud CLI
# fill the FILL_ME lines (domain, IdP, keys), then:
cd infra/digitalocean && terraform init && terraform apply     # or infra/aws
cd ../..
# .env.production renders itself on first deploy (or by hand:
# terraform output -raw env_production > ../../.env.production)
```

Everything infrastructure is the ground's job and never a runbook's: TLS (DO managed Let's Encrypt / AWS ACM at the load balancer — no proxy software on the VM), DNS records, the cloud firewall (SSH and Dozzle admin-IP-only), Postgres (fresh, adopted, or BYO — see [02-database](./02-database.md)), and Redis (always provisioned, TLS).

### Sizes

`size` in terraform.tfvars scales the box and the stores, never the topology (all sizes are single-VM). When multi-VM Active-Active arrives it will scale the app tier only: UMAP stays one shared service (`UMAP_SERVICE_URL`), because spatial coordinates are only comparable through the same trained model instance.

| Size | Guide |
| --- | --- |
| `small` | POC / first deployment |
| `medium` | Growing usage |
| `large` | Heavy usage |

### External Dependencies

| Component      | Requirement                 | Notes                                                                |
| -------------- | --------------------------- | -------------------------------------------------------------------- |
| **PostgreSQL** | 14+                         | Terraform-provisioned by default; adopt or BYO via terraform.tfvars  |
| **Redis**      | 7+                          | Always Terraform-provisioned (managed, TLS)                          |
| **Domain**     | DNS A records               | `api.<domain>` → the load balancer IP (Terraform prints it; can create the records too) |
| **TLS**        | The ground's load balancer  | DO managed Let's Encrypt / AWS ACM; on-prem brings its own terminator (443 → :4105, idle ≥ 3600s) |

### Supported Platforms

- **Cloud grounds:** DigitalOcean (`infra/digitalocean`), AWS (`infra/aws`)
- **On-prem:** any Ubuntu 22.04+ / Debian 12 VM — you own firewall and TLS, then Deploy and Operate are identical

---

## Deploy (the CLI)

```bash
# First time — everything: install, database, hardening, verify
unoverse deploy init

# Every deploy after that
unoverse deploy          # pull latest platform images + restart
```

Each phase of `init` stays available on its own for re-runs: `deploy db`, `deploy harden`, `deploy test`.

The CLI generates a temporary Ansible inventory from `.env.production` on every run (`DEPLOY_HOST`/`DEPLOY_USER`), so there is no inventory file to maintain.

Your own work (nodes, design, prompts) never rides a deploy: it arrives via `unoverse update` (git), the Marketplace (per item, database-driven), or Studio publish.

---

## Operate (the runbooks)

| Runbook                                                                                                              | Description                                                                      | Command                     |
| -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- | --------------------------- |
| [01-core](./01-core.md)                                                                                              | Deploy core app services                                                         | `unoverse deploy init` / `deploy` |
| [02-database](./02-database.md)                                                                                      | Database modes, tables, relocation                                               | `unoverse deploy db`        |
| [04-harden](./04-harden.md)                                                                                          | Security hardening                                                               | `unoverse deploy harden`    |
| [06-test](./06-test.md)                                                                                              | Verify connectivity and health                                                   | `unoverse deploy test`      |
| [09-restart-rebuild](./09-restart-rebuild.md)                                                                        | Restart & rebuild decision table                                                 | —                           |
| [Architecture Diagrams](https://unoverse-platform.github.io/starter/docs/runbooks/architecture-diagrams/index.html) | Interactive system architecture diagrams ([local](./architecture-diagrams/index.html)) | —                           |

**Logs** need no runbook: Dozzle runs by default at `http://<VM_IP>:8080` (admin-IP-only via the cloud firewall), streams straight from the Docker socket, and stores nothing. Log growth is capped by `json-file` rotation (10 MB × 3 per service) in `docker-compose.yml`. Enterprise ships logs to its own SIEM by pointing the Docker logging driver there instead.

---

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
│  Written by: Terraform (terraform output -raw env_production)    │
│  Read by: unoverse deploy / Ansible                               │
│  Deployed to: /opt/gravity/.env on the server                    │
│  Contains: VM target, real Redis, real DB, TLS enabled, DOMAIN,  │
│            and the master CREDENTIAL_ENCRYPTION_KEY              │
└──────────────────────────────────────────────────────────────────┘
```

**Key rules:**

- Both files are **gitignored** — they contain secrets and are never committed
- `.env.example` is the template for local dev
- `.env.production` has no template and is never typed: `unoverse deploy` renders it from your applied ground when missing, and it carries the master `CREDENTIAL_ENCRYPTION_KEY` — back it up with the database, never hand-edit it (change terraform.tfvars, re-apply, delete the file, redeploy)
- On the server, `unoverse deploy` places `.env.production` at `/opt/gravity/.env` where `docker compose` reads it
- `DEPLOY_HOST` and `DEPLOY_USER` are deployment-only — they tell Ansible where to SSH

**How `DOMAIN` drives **Canvas** URLs:**
When `DOMAIN=yourdomain.com` is set, `docker-compose.yml` automatically derives:

- `VITE_API_URL=https://api.yourdomain.com`
- `VITE_SERVER_WS_URL=wss://api.yourdomain.com`

When `DOMAIN` is unset (local dev), set `API_URL=http://localhost:4105` in `.env` — **Canvas** calls the platform's public listener (unoverse `:4105`) directly.

---

## Prerequisites

- Terraform 1.5+ and your cloud CLI (doctl or aws) on your machine
- Ansible installed locally (`pip install ansible`)
- DOCR token for pulling images (from your Unoverse admin)
