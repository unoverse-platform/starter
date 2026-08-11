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

# The catalogue this universe installs from (MARKETPLACE.md §5).
#
# DEFAULTS TO THE OFFICIAL MARKETPLACE (decided 2026-08-03). It used to have none, on the
# rule that a URL is never hardcoded — right for a URL only the operator can know, wrong for
# this one: the official catalogue is the platform's own address, the same for every
# universe, and requiring each developer to paste it made "install from the marketplace" a
# setup step instead of a thing that works.
#
# Set it to your own to point elsewhere, or to "" for local items only — which is still the
# correct state for an air-gapped estate, and still not an error.
variable "marketplace_url" {
  description = "Base URL of the marketplace catalogue. Empty = local items only."
  type        = string
  default     = "https://unoverse-marketplace-4hlb9.ondigitalocean.app"
}

# ── The credential master key: BRING YOUR OWN when you bring your own database ──
#
# THE KEY BELONGS TO THE DATA, NOT TO THE DEPLOYMENT. It decrypts the credential rows in
# the database it is paired with, so any two environments sharing a database must share
# this key. Terraform generating a fresh one per deployment is right for a fresh database
# and WRONG for byo_postgres_url / existing_pg_cluster_name pointing at a database that
# already holds credentials: the deploy renders a new key and every stored credential
# fails with OpenSSL "bad decrypt". The same trap catches a local .env pointed at this
# universe's database (SECURITY.md § Credential encryption at rest).
#
# DIGITALOCEAN ONLY, deliberately. AWS always provisions its own RDS instance, so its
# database is always new and a generated key is always right; a variable there would be
# a way to get it wrong with no case that needs it.
#
# Leave it empty for a fresh database and Terraform generates one, which is the common
# case. Set it to the key that already encrypted those rows when the database is not new,
# and keep the two in step from then on.
variable "credential_encryption_key" {
  description = "Master key for credentials at rest. Empty = generate one (fresh database). Set it to the EXISTING key when reusing a database that already holds credentials."
  type        = string
  sensitive   = true
  default     = ""
  validation {
    condition     = var.credential_encryption_key == "" || length(var.credential_encryption_key) >= 32
    error_message = "credential_encryption_key must be at least 32 characters (openssl rand -base64 32)."
  }
}
