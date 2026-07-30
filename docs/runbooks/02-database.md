---
sidebarTitle: "Database Setup"
title: "Runbook: Database Setup"
---

Create database tables and schema.

## Overview

Postgres is provisioned by your Terraform ground, in one of three modes chosen in `terraform.tfvars`:

| Mode | tfvars | What Terraform does |
| --- | --- | --- |
| Fresh (default) | nothing set | Provisions a managed cluster, creates the universe's db, user, and connection pool |
| Adopt existing | `existing_pg_cluster_name` | Adds the universe's own db/user/pool to YOUR cluster, touching nothing else |
| Bring your own | `byo_postgres_url` | Uses your URL verbatim; you own pooling and extensions |

Either way the rendered production configuration arrives complete: `DATABASE_URL` (pooled, for the services) and `DATABASE_URL_DIRECT` (for migrations). You never write a connection string by hand.

## Steps

### 1. Run Database Setup

```bash
unoverse deploy db
```

This applies the baseline migration (idempotent, safe to re-run): it enables the `vector` and `pg_stat_statements` extensions and creates the complete schema — 26 tables covering:

- **Workflows** — `workflows`, `workflow_executions`, `workflow_snapshots`, `node_traces`
- **Nodes and marketplace** — `node_definitions`, `service_definitions`, `installed_plugins`, `items`, `publish_keys`
- **Credentials and usage** — `credentials` (encrypted at rest with the master key), `token_usage`, `analytics_events`
- **Memory and profiles** — `memories`, `user_profiles`, `goals`, `raw_messages`, `knowledge_docs`
- **Spatial and content** — the `dictionary_*` family (chunks, ingestion, need states), `content_sources`
- **Evaluation and security** — `eval_runs`, `security_attack_corpus`, `security_run_results`

The migration file itself is the authoritative list: `engine/migrations/001_baseline.sql`.

### 2. Verify

```bash
unoverse deploy test    # includes DB, Redis, and API endpoint checks
```

## BYO Postgres Only

With `byo_postgres_url`, the ground manages nothing about your database, so the requirements are yours to meet:

| Requirement | Value |
| --- | --- |
| PostgreSQL version | 14+ |
| Extensions | `vector`, `pg_stat_statements` must be allowed (managed providers gate them; self-hosted: `apt install postgresql-14-pgvector`) |
| SSL | `?sslmode=require` on the URL |
| Connections | Budget for ~20; front with PgBouncer (transaction mode) if the ceiling is tight |
| Network | The VM's IP allowed at your database's firewall |

## Troubleshooting

| Issue              | Cause                      | Fix                                        |
| ------------------ | -------------------------- | ------------------------------------------ |
| Connection refused | Firewall blocking          | Managed modes: `terraform apply` maintains trusted sources. BYO: add the VM IP yourself |
| SSL required       | Missing `?sslmode=require` | BYO only — add SSL mode to your URL        |
| Auth failed        | Wrong credentials          | `terraform apply`, delete `.env.production`, redeploy (deploy re-renders it) |
| Extension denied   | Provider gates extensions  | BYO only — allow `vector` in your provider's console |

## Relocating Data Between Databases

To move data between database providers (e.g., Timescale → DigitalOcean):

```bash
cd ansible
ansible-playbook playbooks/relocate-db.yml \
  -e 'source_db=postgres://user:pass@source-host:port/db?sslmode=require' \
  -e 'target_db=postgres://user:pass@target-host:port/db?sslmode=require'
```

This will:

1. Install PostgreSQL 17 client tools (if needed)
2. `pg_dump` the source database (read-only — source is not modified)
3. Enable `vector` and `pg_stat_statements` extensions on target
4. `pg_restore` to the target database
5. Update `/opt/gravity/.env` with the new `DATABASE_URL`
6. Restart the unoverse service

**Note:** Timescale-specific errors (continuous_agg, bgw_job) during restore are expected and harmless — all application tables migrate correctly.

After relocating, verify with `unoverse deploy test`.

## Next Steps

- [04-harden.md](./04-harden.md) - Security hardening
- [06-test.md](./06-test.md) - Verify connectivity
