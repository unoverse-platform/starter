# The Universe — DigitalOcean ground (docs/architecture/INFRASTRUCTURE.md)
#
# Same five-input contract as infra/aws, DO implementation: Droplet + Managed
# Postgres (fronted by its built-in PgBouncer, per the Postgres law) + Managed
# Redis + DO Load Balancer with a managed Let's Encrypt cert (native ingress —
# Caddy is retired) + cloud firewall (the ground owns the firewall; Docker
# cannot bypass what never reaches the box). Terraform provisions and renders
# .env.production; `unoverse deploy` does the rest.

terraform {
  required_version = ">= 1.5"
  required_providers {
    digitalocean = { source = "digitalocean/digitalocean", version = "~> 2.40" }
    random       = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

provider "digitalocean" {
  # Empty token falls through to the DIGITALOCEAN_TOKEN env var.
  token = var.do_token != "" ? var.do_token : null
}

# ── Size table (INFRASTRUCTURE.md § Sizes — the numbers live in the contract) ──
locals {
  sizes = {
    small = {
      droplet = "s-4vcpu-16gb-amd" # 4 vCPU / 16 GB — the POC box
      pg      = "db-s-1vcpu-1gb"   # ~22 backend connections (~19 usable) — hence the pool
      redis   = "db-s-1vcpu-1gb"
      # Connection budget: engine 8 / legacy 4 / memory 4 (+2 ops, +1 reserve = 19)
      pool_engine = 8
      pool_legacy = 4
      pool_memory = 4
      pgbouncer   = 17 # backend connections the managed pool holds (leaves 5 direct: migrations + ops)
    }
    medium = {
      droplet     = "g-8vcpu-32gb"
      pg          = "db-s-2vcpu-4gb"
      redis       = "db-s-1vcpu-2gb"
      pool_engine = 20
      pool_legacy = 8
      pool_memory = 10
      pgbouncer   = 40
    }
    large = {
      droplet     = "m-8vcpu-64gb" # memory-optimized: the engine is ONE event loop — RAM, not cores
      pg          = "db-s-4vcpu-8gb"
      redis       = "db-s-2vcpu-4gb"
      pool_engine = 40
      pool_legacy = 12
      pool_memory = 20
      pgbouncer   = 80
    }
  }
  s = local.sizes[var.size]

  # Postgres modes (variables.tf): external URL > existing DO cluster > provision.
  pg_external  = var.byo_postgres_url != ""
  pg_adopt     = !local.pg_external && var.existing_pg_cluster_name != ""
  provision_pg = !local.pg_external && !local.pg_adopt
  pg_managed   = local.pg_adopt || local.provision_pg # any DO-managed mode

  # Domainless-first (DECIDED 2026-07-31): no domain = no cert, the LB speaks
  # plain HTTP on its IP. Setting domain later and re-applying upgrades the SAME
  # LB in place — cert issued, HTTPS rules swap in, HTTP redirect on.
  has_domain = var.domain != ""
  api_host   = "api.${var.domain}"
}

# The adopted cluster's facts (id/host/port) when reusing an existing one.
data "digitalocean_database_cluster" "existing_pg" {
  count = local.pg_adopt ? 1 : 0
  name  = var.existing_pg_cluster_name
}

locals {
  # The cluster every universe resource (db/user/pool/firewall) attaches to.
  pg_cluster_id   = local.pg_adopt ? data.digitalocean_database_cluster.existing_pg[0].id : (local.provision_pg ? digitalocean_database_cluster.pg[0].id : "")
  pg_cluster_host = local.pg_adopt ? data.digitalocean_database_cluster.existing_pg[0].private_host : (local.provision_pg ? digitalocean_database_cluster.pg[0].private_host : "")
  pg_cluster_port = local.pg_adopt ? data.digitalocean_database_cluster.existing_pg[0].port : (local.provision_pg ? digitalocean_database_cluster.pg[0].port : 25060)
}

data "digitalocean_ssh_key" "operator" {
  name = var.ssh_key_name
}

# ── The box ───────────────────────────────────────────────────────────────────
resource "digitalocean_droplet" "app" {
  name     = "${var.name}-app"
  region   = var.region
  size     = local.s.droplet
  image    = "ubuntu-22-04-x64"
  ssh_keys = [data.digitalocean_ssh_key.operator.id]
}

# ── Firewall: the ground owns it (harden.yml's ufw could be bypassed by
# Docker's iptables rules; a cloud firewall cannot) ────────────────────────────
resource "digitalocean_firewall" "app" {
  name        = "${var.name}-app"
  droplet_ids = [digitalocean_droplet.app.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.admin_cidr]
  }
  # Dozzle log viewer — POC size ships it ON, admin-only (INFRASTRUCTURE.md size table).
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = [var.admin_cidr]
  }
  # The public surface arrives ONLY through the load balancer.
  inbound_rule {
    protocol                  = "tcp"
    port_range                = "4105"
    source_load_balancer_uids = [digitalocean_loadbalancer.public.id]
  }
  # Canvas (operator UI): the DO LB has NO host-based routing (Caddy did), so the
  # public LB carries ONLY the api host → :4105. Canvas is an OPERATOR tool —
  # admin-only direct access, same trust ring as SSH and Dozzle. It still calls
  # the platform at https://api.<domain> like any client.
  # POC (canvas_public = true): :3001 ALSO accepts the public LB, which serves
  # Canvas at https://api.<domain>:3001. Direct-IP access stays admin-only either way.
  inbound_rule {
    protocol                  = "tcp"
    port_range                = "3001"
    source_addresses          = [var.admin_cidr]
    source_load_balancer_uids = var.canvas_public ? [digitalocean_loadbalancer.public.id] : []
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ── Native ingress: DO LB + managed Let's Encrypt cert (Caddy retired) ────────
# NOTE (INFRASTRUCTURE.md § Ingress): DO caps http idle timeout at 600s — set to
# the cap; long-quiet SSE/WS sessions must survive a reconnect (smoke-test item).
resource "digitalocean_certificate" "api" {
  count   = local.has_domain ? 1 : 0
  name    = "${var.name}-api"
  type    = "lets_encrypt"
  # canvas.<domain> rides the SAME certificate as a SAN (and the same LB): the
  # clean hostname costs nothing — only the PORT cannot be dropped, because DO
  # LBs cannot host-route (DECIDED 2026-07-29: one LB, port in the URL).
  domains = var.canvas_public ? [local.api_host, "canvas.${var.domain}"] : [local.api_host]
}

resource "digitalocean_loadbalancer" "public" {
  name                     = "${var.name}-lb"
  region                   = var.region
  droplet_ids              = [digitalocean_droplet.app.id]
  redirect_http_to_https   = local.has_domain # domainless serves HTTP itself, nothing to redirect to
  http_idle_timeout_seconds = 600 # DO's maximum

  # With a domain: HTTPS 443 with the managed cert. Without: plain HTTP 80 on
  # the LB IP. Same port meanings for the developer either way (API on the root).
  dynamic "forwarding_rule" {
    for_each = local.has_domain ? [1] : []
    content {
      entry_port       = 443
      entry_protocol   = "https"
      target_port      = 4105
      target_protocol  = "http"
      certificate_name = one(digitalocean_certificate.api[*].name)
    }
  }
  dynamic "forwarding_rule" {
    for_each = local.has_domain ? [] : [1]
    content {
      entry_port      = 80
      entry_protocol  = "http"
      target_port     = 4105
      target_protocol = "http"
    }
  }

  # POC (canvas_public = true, DECIDED 2026-07-29): Canvas rides the SAME LB on a
  # second port — https://canvas.<domain>:3001 (a SAN on the api certificate, an A record to this same LB). ONE load balancer total: DO LBs can't
  # host-route, and a clean second hostname would cost a second LB; the POC takes
  # the port in the URL instead. Domainless: same second port, plain HTTP.
  dynamic "forwarding_rule" {
    for_each = var.canvas_public ? [1] : []
    content {
      entry_port       = 3001
      entry_protocol   = local.has_domain ? "https" : "http"
      target_port      = 3001
      target_protocol  = "http"
      certificate_name = one(digitalocean_certificate.api[*].name)
    }
  }


  healthcheck {
    port     = 4105
    protocol = "http"
    path     = "/health"
  }
}

resource "digitalocean_record" "canvas" {
  count  = local.has_domain && var.canvas_public && var.manage_dns ? 1 : 0
  domain = var.domain
  type   = "A"
  name   = "canvas"
  value  = digitalocean_loadbalancer.public.ip
  ttl    = 300
}

# Optional DNS (manage_dns = true and the domain hosted on DO).
resource "digitalocean_record" "api" {
  count  = local.has_domain && var.manage_dns ? 1 : 0
  domain = var.domain
  type   = "A"
  name   = "api"
  value  = digitalocean_loadbalancer.public.ip
  ttl    = 300
}

# ── Postgres: Managed PG fronted by its built-in PgBouncer (the law) ──────────
resource "digitalocean_database_cluster" "pg" {
  count      = local.provision_pg ? 1 : 0
  name       = "${var.name}-pg"
  engine     = "pg"
  version    = "16"
  size       = local.s.pg
  region     = var.region
  node_count = 1
}

resource "digitalocean_database_db" "universe" {
  count      = local.pg_managed ? 1 : 0
  cluster_id = local.pg_cluster_id
  name       = "universe"
}

resource "digitalocean_database_user" "universe" {
  count      = local.pg_managed ? 1 : 0
  cluster_id = local.pg_cluster_id
  name       = "universe"
}

# Transaction-mode pool: ~hundreds of client connections over `pgbouncer` backend
# slots. Services use the POOLED url; migrations use the DIRECT url
# (DATABASE_URL_DIRECT — db-setup prefers it; DDL doesn't ride transaction mode).
resource "digitalocean_database_connection_pool" "universe" {
  count      = local.pg_managed ? 1 : 0
  cluster_id = local.pg_cluster_id
  name       = "universe-pool"
  mode       = "transaction"
  size       = local.s.pgbouncer
  db_name    = digitalocean_database_db.universe[0].name
  user       = digitalocean_database_user.universe[0].name
}

resource "digitalocean_database_firewall" "pg" {
  count      = local.pg_managed ? 1 : 0
  cluster_id = local.pg_cluster_id
  rule {
    type  = "droplet"
    value = digitalocean_droplet.app.id
  }
}

# ── Redis: ALWAYS ours (Managed Redis, TLS, droplet-only). Never BYO — it is
# the shared-state backbone and the active/active future; the stack owns it. ──
resource "digitalocean_database_cluster" "redis" {
  name       = "${var.name}-redis"
  engine     = "redis"
  version    = "7"
  size       = local.s.redis
  region     = var.region
  node_count = 1
}

resource "digitalocean_database_firewall" "redis" {
  cluster_id = digitalocean_database_cluster.redis.id
  rule {
    type  = "droplet"
    value = digitalocean_droplet.app.id
  }
}

# ── Per-deployment credential-encryption key (SECURITY.md § Credential
# encryption at rest): no deployment ever runs on the committed default. ──────
resource "random_password" "credential_key" {
  length  = 44
  special = false
}
