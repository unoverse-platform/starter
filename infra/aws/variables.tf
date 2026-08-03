# NO DEFAULTS ON EITHER OF THESE — see the same note in infra/digitalocean/variables.tf.
# Where it runs and what it is called are the developer's answers, and a default quietly
# supplies mine instead.
variable "region" {
  description = "AWS region. Must have Bedrock model access enabled for the models you use."
  type        = string
}

variable "name" {
  description = "Prefix for every resource (also the Cognito domain prefix, so keep it dns-safe), and the resource group they are tagged into."
  type        = string
}

variable "admin_cidr" {
  description = "The ONLY CIDR allowed to SSH (deploys + ./unoverse key). Your IP as x.x.x.x/32."
  type        = string
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "oauth_callback_urls" {
  description = "OIDC redirect URLs for the SPA client (Canvas/Studio origins, e.g. https://yourdomain.com and http://localhost:5173 for dev)."
  type        = list(string)
}

variable "admin_email" {
  description = "The initial ADMIN user's email. Created in the Cognito pool and placed in every role group (Cognito emails an invite with a temporary password). This is the platform admin — a Cognito user, not an IAM one."
  type        = string
}

variable "roles" {
  description = "This deployment's RBAC roles, always noun:verb (matched by node manifests' requires.role). Each becomes a Cognito group; membership rides the token's roles/permissions claims. The two platform permissions (workflow:author, marketplace:publish) are always created and need not be listed."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for r in var.roles : can(regex("^[a-z][a-z0-9_-]*:[a-z][a-z0-9_-]*$", r))])
    error_message = "Every role must be noun:verb (lowercase), e.g. finance:approve — the same grammar the node linter enforces."
  }
}

# ── Added 2026-07-29: parity with infra/digitalocean ──────────────────────────

variable "size" {
  description = "Deployment size (INFRASTRUCTURE.md size table): small = POC box."
  type        = string
  default     = "small"
  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = "size must be small, medium or large."
  }
}

variable "domain" {
  description = "OPTIONAL — the same law on every ground. Empty (the default) = no certificate and no hostnames: the ALB serves plain HTTP on its DNS name (terraform output api_url) — the zero-friction first apply. Set it later and re-apply to upgrade IN PLACE to TLS at api.<domain> (and unoverse.<domain> when canvas_public). Nothing is destroyed by the upgrade."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "OPTIONAL: the domain's Route53 hosted zone id. Set = Terraform creates the DNS records AND auto-validates the ACM cert. Empty = you create the validation CNAME + A records yourself (printed as outputs)."
  type        = string
  default     = ""
}

variable "canvas_public" {
  description = "POC ONLY: Canvas publicly at https://unoverse.<domain> — a HOST RULE on the one ALB (ALBs host-route; no second LB needed, unlike DO). false = Canvas stays admin-only direct :3001 (the standing posture). Add https://unoverse.<domain> to the client origins."
  type        = bool
  default     = false
}

# Service secrets — taken here so the rendered .env.production is COMPLETE;
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

# YOUR public key, uploaded as this universe's EC2 key pair. Deploying means ssh-ing from
# the machine that runs `unoverse deploy`, so the key that must work is the one that machine
# holds — not whichever pair happens to exist in the account. Empty falls back to
# ssh_key_name, for an operator with no local key.
variable "operator_public_key" {
  description = "An ssh public key (the contents of ~/.ssh/id_ed25519.pub). Empty = use ssh_key_name instead."
  type        = string
  default     = ""
}
