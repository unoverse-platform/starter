---
sidebarTitle: "Security Hardening"
title: "Runbook: Security Hardening"
---

Apply security hardening to Gravity Platform VMs. Deliberately NOT part of `deploy init`: verify your POC first, then harden when you decide to keep it.

## Overview

This runbook applies security best practices to production VMs:

- SSH hardening
- Fail2ban for brute-force protection
- Unattended security updates

> **Where is the firewall?** Owned by your ground's Terraform (`infra/`): the DO
> cloud firewall or AWS security groups. There is no host firewall (UFW) by
> design: Docker's iptables rules bypass UFW for published ports, so a host
> firewall protects nothing. The cloud firewall sits in front of the box, where
> traffic structurally cannot bypass it. SSH and Dozzle are admin-IP-only
> (`admin_cidr` in terraform.tfvars); app ports accept the load balancer.

## Prerequisites

- [ ] Core services deployed ([01-core.md](./01-core.md))
- [ ] Database configured ([02-database.md](./02-database.md))
- [ ] Services verified working before hardening

## Steps

### 1. Run Hardening

```bash
unoverse deploy harden
```

### 2. Verify Access Still Works

```bash
# Test SSH (from your machine)
ssh root@<VM_IP>

# Test services
unoverse deploy test
```

## What Gets Configured

### SSH Hardening

- Disable password authentication (keys only)
- Disable root password login
- SSH stays on port 22, reachable only from `admin_cidr` (cloud firewall)

### Fail2ban

- Bans IPs after repeated failed SSH attempts
- 1 hour ban duration (3600 seconds)
- Protects against brute-force attacks

## Troubleshooting

| Issue                 | Cause                    | Fix                                                |
| --------------------- | ------------------------ | -------------------------------------------------- |
| Locked out of SSH     | Your IP changed          | Update `admin_cidr` in terraform.tfvars and `terraform apply`; or use the cloud console |
| Services unreachable  | Cloud firewall rules     | Check the ground: `terraform plan` shows drift     |
| Fail2ban blocking you | Too many failed attempts | Wait 1 hour or unban: `fail2ban-client unban <IP>` |

## Next Steps

- [06-test.md](./06-test.md) - Verify connectivity
