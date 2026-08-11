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
  # Canvas (operator UI). Direct access to :3001 on the droplet stays admin-only, same
  # trust ring as SSH and Dozzle, whatever else is true.
  # With canvas_public: whichever load balancer fronts it may reach :3001 too — the canvas
  # LB when there is a domain, the main one when there is not. Naming both here would open
  # 3001 to an LB that is not serving Canvas in that mode.
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3001"
    source_addresses = [var.admin_cidr]
    source_load_balancer_uids = var.canvas_public ? (
      local.has_domain ? [digitalocean_loadbalancer.canvas[0].id] : [digitalocean_loadbalancer.public.id]
    ) : []
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
  count = local.has_domain ? 1 : 0
  name  = "${var.name}-api"
  type  = "lets_encrypt"
  # canvas.<domain> rides the SAME certificate as a SAN (and the same LB): the
  # clean hostname costs nothing — only the PORT cannot be dropped, because DO
  # LBs cannot host-route (DECIDED 2026-07-29: one LB, port in the URL).
  domains = var.canvas_public ? [local.api_host, "canvas.${var.domain}"] : [local.api_host]
}

resource "digitalocean_loadbalancer" "public" {
  name                      = "${var.name}-lb"
  region                    = var.region
  droplet_ids               = [digitalocean_droplet.app.id]
  redirect_http_to_https    = local.has_domain # domainless serves HTTP itself, nothing to redirect to
  http_idle_timeout_seconds = 600              # DO's maximum

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

  # DOMAINLESS ONLY. Without a hostname there is nothing to route by, so Canvas takes a
  # second port on this LB's IP. With a domain it gets its own load balancer below and a
  # clean https://canvas.<domain> — see the note there.
  dynamic "forwarding_rule" {
    for_each = var.canvas_public && !local.has_domain ? [1] : []
    content {
      entry_port      = 3001
      entry_protocol  = "http"
      target_port     = 3001
      target_protocol = "http"
    }
  }


  healthcheck {
    port     = 4105
    protocol = "http"
    path     = "/health"
  }
}

# CANVAS GETS ITS OWN LOAD BALANCER, so its URL carries no port.
#
# Supersedes the 2026-07-29 decision to run one LB and put :3001 in the URL. A port in a
# hostname is not a URL anyone ships: it breaks the expectation that https means 443, it
# has to be explained to every operator, and it leaks an implementation detail of the
# ingress into the address bar. The reason for it was real — DigitalOcean load balancers
# route on PORT only, never on the Host header, so one LB genuinely cannot serve two
# hostnames — but the conclusion was wrong. The right answer to "the product cannot do
# this" is a second load balancer, not a worse address.
#
# ~$12/month, and only when a domain is set AND Canvas is public. Domainless universes
# keep the second port on the main LB above: with no hostname there is nothing to route by,
# so a second LB would buy nothing.
resource "digitalocean_loadbalancer" "canvas" {
  count                     = local.has_domain && var.canvas_public ? 1 : 0
  name                      = "${var.name}-canvas-lb"
  region                    = var.region
  droplet_ids               = [digitalocean_droplet.app.id]
  redirect_http_to_https    = true
  http_idle_timeout_seconds = 600

  forwarding_rule {
    entry_port       = 443
    entry_protocol   = "https"
    target_port      = 3001
    target_protocol  = "http"
    certificate_name = one(digitalocean_certificate.api[*].name)
  }

  # Canvas has no /health of its own; the root answering is the liveness signal.
  healthcheck {
    port     = 3001
    protocol = "http"
    path     = "/"
  }
}

resource "digitalocean_record" "canvas" {
  count  = local.has_domain && var.canvas_public && var.manage_dns ? 1 : 0
  domain = var.domain
  type   = "A"
  name   = "canvas"
  value  = digitalocean_loadbalancer.canvas[0].ip
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

# NAMED AFTER THE UNIVERSE, not "universe". A cluster can host several universes — that
# is the whole point of adopting one rather than provisioning per stack — and a hardcoded
# name means the second one either collides with the first or, worse, attaches to it and
# silently shares its data. Everything else on this ground is already ${var.name}-prefixed.
resource "digitalocean_database_db" "universe" {
  count      = local.pg_managed ? 1 : 0
  cluster_id = local.pg_cluster_id
  name       = var.name
}

resource "digitalocean_database_user" "universe" {
  count      = local.pg_managed ? 1 : 0
  cluster_id = local.pg_cluster_id
  name       = var.name

  # NEVER UPDATE THIS USER IN PLACE. Provider 2.96 grew a `settings` block (Kafka and
  # OpenSearch ACLs) and an update path that fires whenever it sees any diff on the
  # resource — including one the provider invented itself on refresh. For a Postgres user,
  # which has no settings, that path PUTs an empty body and DigitalOcean rejects it:
  #
  #   400 request is missing the following required fields: user_settings
  #
  # It killed a deploy mid-apply, after the firewall had already changed, on a resource
  # declaring nothing but a name. We create this user once and never modify it — name and
  # cluster_id both force replacement anyway — so there is no update we want, and the
  # safest number of update paths to leave available is zero.
  lifecycle {
    ignore_changes = all
  }
}

# Transaction-mode pool: ~hundreds of client connections over `pgbouncer` backend
# slots. Services use the POOLED url; migrations use the DIRECT url
# (DATABASE_URL_DIRECT — db-setup prefers it; DDL doesn't ride transaction mode).
resource "digitalocean_database_connection_pool" "universe" {
  count      = local.pg_managed ? 1 : 0
  cluster_id = local.pg_cluster_id
  name       = "${var.name}-pool"
  mode       = "transaction"
  size       = local.s.pgbouncer
  db_name    = digitalocean_database_db.universe[0].name
  user       = digitalocean_database_user.universe[0].name
}

# ONLY A CLUSTER THIS STACK CREATED. `digitalocean_database_firewall` is AUTHORITATIVE:
# it replaces the whole trusted-sources list rather than adding to it. Applied to an
# ADOPTED cluster it therefore deleted every rule the account already had — the
# operator's own IP, their other droplets, their App Platform apps — and locked them out
# of a database this universe merely borrows. It happened, on 2026-08-01.
#
# So terraform owns the firewall only when it owns the cluster (`provision_pg`). For an
# adopted cluster the CLI appends this droplet to the existing rules instead
# (scripts/lib/deploy.sh), which is additive and leaves everything else alone. A universe
# never takes ownership of a database it did not create.
resource "digitalocean_database_firewall" "pg" {
  count      = local.provision_pg ? 1 : 0
  cluster_id = local.pg_cluster_id
  rule {
    type  = "droplet"
    value = digitalocean_droplet.app.id
  }
}

# ── Valkey: ALWAYS ours (managed, TLS, droplet-only). Never BYO — it is the
# shared-state backbone and the active/active future; the stack owns it.
#
# VALKEY, NOT REDIS. DigitalOcean retired the `redis` engine: /v2/databases/options now
# lists valkey and no redis at all. Asking for a dead engine failed with "region 'lon1'
# is not valid", because an unknown engine matches no region — an error that sent us
# looking at the region for as long as it took to ask the API what engines exist.
# Valkey speaks the Redis protocol, so every client here is unchanged. ──
resource "digitalocean_database_cluster" "redis" {
  name       = "${var.name}-redis"
  engine     = "valkey"
  version    = "8"
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

# The key that actually ships: the operator's when they brought one (a database that
# already holds credentials keeps the key that encrypted them), otherwise the generated
# one above. See variables.tf § credential master key.
locals {
  credential_encryption_key = var.credential_encryption_key != "" ? var.credential_encryption_key : random_password.credential_key.result
}

# ── One project, so a universe looks like one thing ───────────────────────────
#
# Without this, a universe's parts scatter through the DigitalOcean default project among
# everything else the account runs, and "what does this universe own" has no answer you
# can see. The project is named after the universe, so the console shows the server, the
# cache and the load balancer as one group.
#
# ONLY WHAT THIS STACK OWNS. An adopted Postgres belongs to whoever created it; moving it
# into this project would quietly reorganise someone else's resource.
resource "digitalocean_project" "universe" {
  name        = var.name
  description = "unoverse universe: ${var.name}"
  purpose     = "Web Application"
  environment = var.size == "small" ? "Development" : "Production"
  # EVERY resource this stack creates, or the dashboard lies. The Canvas load balancer was
  # added without being listed here, so it stayed in the account's default project while
  # the rest of the universe sat in this one: two views each reporting "LOAD BALANCERS (1)"
  # and no single place showing what this universe actually is. Anything added below must
  # be added here in the same commit.
  resources = compact([
    digitalocean_droplet.app.urn,
    digitalocean_loadbalancer.public.urn,
    local.has_domain && var.canvas_public ? digitalocean_loadbalancer.canvas[0].urn : "",
    digitalocean_database_cluster.redis.urn,
    local.provision_pg ? digitalocean_database_cluster.pg[0].urn : "",
  ])
}
