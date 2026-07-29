# Gravity Platform Ansible Automation

Ansible playbooks for deployment, upgrades, and operations.

## Quick Start (Single VM)

There is no inventory to configure — deployments are single-VM by contract
(INFRASTRUCTURE.md) and `unoverse deploy` builds a temporary inventory from
`.env.production` each run.
Just use `.env.production` at the project root:

```bash
# 1. Configure production environment (Terraform renders it, complete)
cd infra/digitalocean && terraform apply
terraform output -raw env_production > ../../.env.production

# 2. Deploy
gravity deploy

# 3. Verify
gravity deploy test
```

The `gravity deploy` command reads `.env.production`, builds a temporary inventory, and runs the playbooks automatically.

## Structure

```
ansible/
├── playbooks/                  # All playbooks
├── templates/
└── ansible.cfg
```

## Direct Ansible Usage

For advanced use or multi-VM enterprise deployments:

```bash
cd ansible

# Single VM (reads .env.production from project root)

# Multi-VM (target specific groups)
```

## Playbooks

| Playbook                | Purpose                                      |
| ----------------------- | -------------------------------------------- |
| `install.yml`           | Fresh install (Docker, images, services)     |
| `deploy-packages.yml`   | Deploy packages (rsync from local + build)   |
| `db-setup.yml`          | Database setup and migrations                |
| `relocate-db.yml`       | RELOCATE a database (dump/restore to another server) — NOT schema migrations (that is db-setup) |
| `rollback.yml`          | Rollback to previous version                 |
| `health-check.yml`      | Verify all services healthy                  |
| `backup.yml`            | Backup UMAP models                           |
| `restore.yml`           | Restore UMAP models from backup              |
| `harden.yml`            | Security hardening (SSH, firewall, fail2ban) |
| `test-connectivity.yml` | Test VM connectivity and ports               |

## Requirements

- Ansible 2.12+
- SSH access to target VMs
- DOCR token (for pulling Docker images from DigitalOcean Container Registry)
