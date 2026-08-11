# Everything .env.production needs — the rendered file is COMPLETE, nothing
# is hand-edited afterwards:
#   terraform output -raw env_production > ../../.env.production
#   unoverse deploy

locals {
  # Pooled URL for the services (transaction-mode PgBouncer; prepared statements off),
  # direct URL for migrations. BYO: your URL is used verbatim for both — you own the
  # pooling story against your own max_connections (INFRASTRUCTURE.md § BYO).
  # Managed modes (provisioned OR adopted existing cluster): the universe's own
  # user/db/pool were created on local.pg_cluster_id either way.
  pg_pooled = local.pg_managed ? "postgresql://${digitalocean_database_user.universe[0].name}:${digitalocean_database_user.universe[0].password}@${digitalocean_database_connection_pool.universe[0].private_host}:${digitalocean_database_connection_pool.universe[0].port}/${digitalocean_database_connection_pool.universe[0].name}?sslmode=require&pgbouncer=true" : var.byo_postgres_url
  pg_direct = local.pg_managed ? "postgresql://${digitalocean_database_user.universe[0].name}:${digitalocean_database_user.universe[0].password}@${local.pg_cluster_host}:${local.pg_cluster_port}/${digitalocean_database_db.universe[0].name}?sslmode=require" : var.byo_postgres_url

  # THE ADMIN URL EXISTS FOR EXACTLY ONE STATEMENT. PostgreSQL 15+ no longer grants CREATE
  # on schema public to PUBLIC, and DigitalOcean owns every database it creates as doadmin.
  # So the universe user can connect and can create nothing: the first migration dies on
  # "permission denied for schema public" after the extensions step reports OK, which reads
  # like the database is fine. Only the cluster's admin can hand over those rights.
  #
  # It is a separate output and NOT part of env_production on purpose. The server holds the
  # universe user's credentials and must never hold the cluster admin's — deploy reads this,
  # spends it on one GRANT, and it goes no further.
  pg_admin_user = local.pg_adopt ? data.digitalocean_database_cluster.existing_pg[0].user : (local.provision_pg ? digitalocean_database_cluster.pg[0].user : "")
  pg_admin_pass = local.pg_adopt ? data.digitalocean_database_cluster.existing_pg[0].password : (local.provision_pg ? digitalocean_database_cluster.pg[0].password : "")
  pg_admin_url  = local.pg_managed ? "postgresql://${local.pg_admin_user}:${local.pg_admin_pass}@${local.pg_cluster_host}:${local.pg_cluster_port}/${digitalocean_database_db.universe[0].name}?sslmode=require" : ""

  # Redis is always ours — provisioned above, no BYO branch.
  redis_host     = digitalocean_database_cluster.redis.private_host
  redis_port     = digitalocean_database_cluster.redis.port
  redis_password = digitalocean_database_cluster.redis.password
  redis_tls      = true
}

output "deploy_host" {
  description = "The droplet's public IP (.env.production DEPLOY_HOST). Point api.<domain> at the LB IP, not this."
  value       = digitalocean_droplet.app.ipv4_address
}

output "lb_ip" {
  description = "The load balancer's IP — api.<domain>'s A record target (created automatically when manage_dns = true)."
  value       = digitalocean_loadbalancer.public.ip
}

# Canvas's own load balancer address. Read by `unoverse where` so a hostname resolving to
# something else can be reported as stale DNS rather than as a dead service.
output "canvas_lb_ip" {
  description = "The Canvas load balancer's IP — canvas.<domain>'s A record target. Empty when Canvas is not public or there is no domain."
  value       = length(digitalocean_loadbalancer.canvas) > 0 ? digitalocean_loadbalancer.canvas[0].ip : ""
}

output "canvas_url" {
  description = "Public Canvas URL (canvas_public = true only) — add it to the IdP's allowed origins."
  value       = var.canvas_public ? (local.has_domain ? "https://canvas.${var.domain}" : "http://${digitalocean_loadbalancer.public.ip}:3001") : "canvas is admin-only (direct http://<droplet-ip>:3001 from admin_cidr)"
}

output "api_url" {
  description = "The API base URL as deployed — https://api.<domain> with a domain, http://<lb-ip> without one."
  value       = local.has_domain ? "https://${local.api_host}" : "http://${digitalocean_loadbalancer.public.ip}"
}

# The database user this universe owns. db-setup grants it rights on its own schema, and
# the name follows var.name now, so the playbook can no longer assume "universe".
output "pg_user" {
  value       = length(digitalocean_database_user.universe) > 0 ? digitalocean_database_user.universe[0].name : ""
  description = "This universe's database user, when the ground manages one"
}

# Read by deploy for the one-time schema grant, never written to the server. Empty when
# the database is BYO: somebody else's cluster, whose permissions are theirs to run.
output "pg_admin_url" {
  value       = local.pg_admin_url
  description = "Cluster admin connection to this universe's database — used once, to grant the universe user rights on schema public"
  sensitive   = true
}

output "env_production" {
  sensitive   = true
  description = "Rendered .env.production — complete, write to a file and deploy"
  value       = <<-ENV
    # UNIVERSE (DigitalOcean) — generated by infra/digitalocean. COMPLETE:
    # do not hand-edit; change terraform.tfvars and re-render instead.

    # Deploy target
    DEPLOY_HOST=${digitalocean_droplet.app.ipv4_address}
    DEPLOY_USER=root

    # Container registry
    DOCR_TOKEN=${var.docr_token}

    # Database (pooled via managed PgBouncer, transaction mode — the Postgres law).
    # Migrations use the DIRECT url (db-setup prefers DATABASE_URL_DIRECT).
    DATABASE_URL=${local.pg_pooled}
    DATABASE_URL_DIRECT=${local.pg_direct}

    # Connection budget (INFRASTRUCTURE.md, size = ${var.size})
    DB_POOL_ENGINE=${local.s.pool_engine}
    DB_POOL_ENGINE_LEGACY=${local.s.pool_legacy}
    DB_POOL_MEMORY=${local.s.pool_memory}

    # Credential encryption at rest — per-deployment, generated by Terraform.
    # Back this up with the database (a DB backup is unreadable without it).
    CREDENTIAL_ENCRYPTION_KEY=${local.credential_encryption_key}

    # Redis (managed, TLS)
    REDIS_HOST=${local.redis_host}
    REDIS_PORT=${local.redis_port}
    REDIS_PASSWORD=${local.redis_password}
    REDIS_TLS=${local.redis_tls}
    REDIS_NAMESPACE=universe

    # OIDC — byo (Auth0 today): the tenant is authoritative for roles/permissions.
    AUTH_ISSUER=${var.auth_issuer}
    AUTH_CLIENT_ID=${var.auth_client_id}
    AUTH_AUDIENCE=${var.auth_audience}

    # Service keys
    OPENAI_API_KEY=${var.openai_api_key}
    HYPERBROWSER_API_KEY=${var.hyperbrowser_api_key}

    # Marketplace catalogue (MARKETPLACE.md §5). Empty = local items only.
    UNOVERSE_MARKETPLACE_URL=${var.marketplace_url}

    # Ingress. With a domain: DOMAIN drives every URL (compose derives
    # https://api.<domain>). Without one (POC): DOMAIN stays empty and the
    # explicit URLs below point at the load balancer's IP over plain HTTP.
    # To upgrade later: set domain in terraform.tfvars, terraform apply,
    # re-render this file, unoverse deploy. Nothing is destroyed.
    DOMAIN=${var.domain}
    ${local.has_domain ? "" : "API_URL=http://${digitalocean_loadbalancer.public.ip}"}
    ${local.has_domain ? "" : "VITE_SERVER_WS_URL=ws://${digitalocean_loadbalancer.public.ip}"}
    ${local.has_domain ? "" : "UNOVERSE_URL=http://${digitalocean_loadbalancer.public.ip}"}
  ENV
}
