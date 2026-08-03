variable "do_token" {
  description = "DigitalOcean API token (or set DIGITALOCEAN_TOKEN in the environment and leave this empty)."
  type        = string
  default     = ""
  sensitive   = true
}

# NO DEFAULTS ON EITHER OF THESE. They used to default to "lon1" and "universe-poc", which
# meant a tfvars missing them built somebody's universe in London under a placeholder name
# and reported success. Where it runs and what it is called are the developer's answers, so
# terraform should refuse to plan without them rather than quietly supply mine.
variable "region" {
  description = "DigitalOcean region for everything (doctl compute region list)."
  type        = string
}

variable "name" {
  description = "Prefix for every resource, and the name of the DigitalOcean project they are grouped under."
  type        = string
}

variable "size" {
  description = "Deployment size (INFRASTRUCTURE.md size table): small = POC box."
  type        = string
  default     = "small"
  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = "size must be small, medium or large."
  }
}

variable "admin_cidr" {
  description = "The ONLY CIDR allowed to SSH (22) and view logs (Dozzle 8080). Your IP as x.x.x.x/32."
  type        = string
}

variable "ssh_key_name" {
  description = "Name of an SSH key already uploaded to the DigitalOcean account."
  type        = string
}

variable "domain" {
  description = "OPTIONAL. Empty (the default) = no certificate and no hostnames: the LB serves plain HTTP on its IP — the zero-friction first apply. Set it later and re-apply to upgrade IN PLACE to TLS at api.<domain> (the DNS A record is created only when manage_dns = true). Nothing is destroyed by the upgrade."
  type        = string
  default     = ""
}

variable "manage_dns" {
  description = "true = the domain's DNS is hosted on DigitalOcean and Terraform manages the records. false = you point api.<domain> at the LB IP yourself (the LB cert still needs the record in place before it can issue)."
  type        = bool
  default     = false
}

# ── Auth: DigitalOcean universes run byo-oidc (Auth0 today) — the tenant is
# authoritative for roles/permissions; Terraform only passes the pointers through
# (INFRASTRUCTURE.md: roles are PROVISIONED only under Cognito on AWS).
variable "auth_issuer" {
  description = "OIDC issuer, e.g. https://your-tenant.auth0.com"
  type        = string
}

variable "auth_client_id" {
  description = "OIDC SPA client id (public by definition)."
  type        = string
}

variable "auth_audience" {
  description = "OIDC audience (the Auth0 API identifier, e.g. gravity-api)."
  type        = string
  default     = "gravity-api"
}

# ── Postgres: three modes, first match wins ───────────────────────────────────
#   1. byo_postgres_url      — fully external DB, URL used verbatim (you own
#                              pooling, backups, reachability).
#   2. existing_pg_cluster_name — an EXISTING DO managed cluster (the usual case:
#                              "I already have Postgres in DO"): Terraform creates
#                              the universe's OWN database, user, transaction
#                              pool, and firewall rule ON that cluster. Your
#                              existing databases are untouched — but the
#                              cluster's max_connections is now SHARED between
#                              your existing workload and this universe's pools;
#                              on the 1GB tier (~22 connections) watch the sum.
#   3. neither set           — Terraform provisions a fresh cluster + pool.
variable "byo_postgres_url" {
  description = "Mode 1: fully external Postgres URL (PG 14+, include sslmode=require). Empty = see existing_pg_cluster_id / provision."
  type        = string
  default     = ""
  sensitive   = true
}

variable "existing_pg_cluster_name" {
  description = "Mode 2: the NAME of an EXISTING DO managed Postgres cluster (doctl databases list). Terraform adds the universe's db/user/pool/firewall to it and creates no cluster."
  type        = string
  default     = ""
}

variable "canvas_public" {
  description = "POC ONLY (decided 2026-07-29): Canvas publicly at https://api.<domain>:3001 — a second port on the ONE load balancer (no second LB, no extra cost; DO LBs cannot host-route, and a clean hostname would cost a second LB). false = Canvas stays admin-only direct :3001 (the standing posture). Add https://api.<domain>:3001 to the IdP's allowed origins."
  type        = bool
  default     = false
}

# Redis is NOT flexible: always provisioned by Terraform (Managed Redis, TLS).
# It is the platform's shared-state backbone (and the active/active future) —
# the stack owns its version and locality. Only Postgres is BYO-able.

# ── Service secrets: taken here so the rendered .env.production is COMPLETE —
# the operator fills terraform.tfvars once and never hand-edits the env file.
variable "docr_token" {
  description = "Container registry token — pulls the platform images."
  type        = string
  sensitive   = true
}

variable "openai_api_key" {
  description = "OpenAI API key — memory server + OpenAI nodes."
  type        = string
  sensitive   = true
}

variable "hyperbrowser_api_key" {
  description = "Optional — page-intelligence features. Empty = feature off."
  type        = string
  default     = ""
  sensitive   = true
}

# The catalogue this universe installs from (MARKETPLACE.md §5). NO DEFAULT, deliberately:
# a URL is never hardcoded and never a fallback, and absent config means no remote
# catalogue — the universe serves what it has on disk and in its rows, which is the correct
# state for development and for air-gapped estates. It reaches the marketplace at install
# time and at no other time.
variable "marketplace_url" {
  description = "Base URL of the marketplace catalogue. Empty = local items only."
  type        = string
  default     = ""
}
