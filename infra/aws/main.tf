# The Universe — AWS POC (docs/architecture/AWS_DEPLOYMENT.md)
#
# One VM + managed Postgres/Redis + Cognito + a scoped Bedrock IAM user.
# Deliberately flat and minimal: this is the POC tier. Terraform provisions,
# the existing `unoverse deploy` (Ansible) deploys — outputs feed .env.production.

terraform {
  required_version = ">= 1.5"
  required_providers {
    # >= 5.83: `user_pool_tier` (the Essentials plan pin) landed in 5.83.0.
    aws     = { source = "hashicorp/aws", version = ">= 5.83, < 6.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
    archive = { source = "hashicorp/archive", version = "~> 2.4" }
    # For the IAM propagation wait below. IAM is eventually consistent and Lambda is the
    # one resource here that reliably outruns it.
    time = { source = "hashicorp/time", version = "~> 0.11" }
  }
}

# ── One universe, one group ───────────────────────────────────────────────────
#
# AWS has no projects. Its equivalent is TAGS, and `default_tags` is the only honest way
# to apply them: it stamps every resource this configuration creates, so nothing is
# forgotten the day someone adds a resource and does not think about tagging. The console
# view comes from the Resource Group below, and the same tag drives cost allocation, which
# a DigitalOcean project cannot do.
#
# It touches ONLY what this stack creates. An adopted database keeps its own tags, in
# keeping with the rule that a universe never takes ownership of what it borrowed
# (INFRASTRUCTURE.md, "Borrowed resources are never owned").
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Universe  = var.name
      ManagedBy = "unoverse"
      Size      = var.size
    }
  }
}

# The console's answer to "what does this universe own". A tag query rather than a
# membership list, so it stays correct as the ground grows without anyone maintaining it.
resource "aws_resourcegroups_group" "universe" {
  name        = var.name
  # AWS Resource Groups allow ONLY [\sa-zA-Z0-9_.-] in a description — no colon, no
  # parentheses. "unoverse universe: name" failed CreateGroup after four minutes of ALB
  # provisioning, and terraform validate cannot see it: the rule lives in the AWS API, not
  # in the schema.
  description = "unoverse universe ${var.name}"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters          = [{ Key = "Universe", Values = [var.name] }]
    })
  }
}

# ── Network: default VPC + two security groups ─────────────────────────────────
# POC uses the default VPC on purpose (no subnet/NAT machinery to own). The trust
# story is the two SGs: the app faces the world on 80/443 only; the data stores
# accept the app SG only. Ports 4101/4105/4106 are NEVER opened here — 443 via
# Caddy is the only application entry, and publish-key minting is on-box (SSH).

data "aws_vpc" "default" {
  default = true
}

# The ALB needs subnets in ≥2 AZs; the default VPC has one per AZ.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── Size table (INFRASTRUCTURE.md § Sizes; AWS instance equivalents) ──────────
locals {
  sizes = {
    small = { # 4 vCPU / 16 GB — the POC box
      instance    = "t3.xlarge"
      pg          = "db.t4g.small"
      redis       = "cache.t4g.micro"
      pool_engine = 8
      pool_legacy = 4
      pool_memory = 4
    }
    medium = { # 8 vCPU / 32 GB
      instance    = "m6i.2xlarge"
      pg          = "db.t4g.medium"
      redis       = "cache.t4g.small"
      pool_engine = 20
      pool_legacy = 8
      pool_memory = 10
    }
    large = { # 8 vCPU / 64 GB — memory-optimized: the engine is ONE event loop
      instance    = "r6i.2xlarge"
      pg          = "db.m6g.large"
      redis       = "cache.t4g.medium"
      pool_engine = 40
      pool_legacy = 12
      pool_memory = 20
    }
  }
  s        = local.sizes[var.size]
  # Domainless-first (DECIDED 2026-07-31, universal across grounds): no domain =
  # no cert, the ALB speaks plain HTTP on its DNS name. Setting domain later and
  # re-applying upgrades the SAME ALB in place — ACM cert, HTTPS listener, redirect.
  has_domain = var.domain != ""
  # Where a person actually goes. Shared by the invitation email and the canvas_url output
  # so the address in the email can never drift from the address in the deploy summary.
  canvas_entry = var.domain != "" ? "https://canvas.${var.domain}" : "http://${aws_lb.public.dns_name}:3001"
  api_host   = "api.${var.domain}"
  dns_auto   = local.has_domain && var.route53_zone_id != ""
}

# The ALB is the ONLY public surface (native ingress, 2026-07-29 — Caddy retired;
# the old 80/443-from-world rules died with it).
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public front door: 80 (redirect) + 443 from the world"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Domainless canvas_public rides a second port (no hostname to host-route by).
  dynamic "ingress" {
    for_each = var.canvas_public && var.domain == "" ? [1] : []
    content {
      from_port   = 3001
      to_port     = 3001
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Gravity platform VM: app ports from the ALB only, SSH/Dozzle from operator"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    # Security group descriptions forbid angle brackets. "api.<domain>" reads naturally in
    # prose and is rejected by the API.
    description     = "Platform api host, from the ALB only"
    from_port       = 4105
    to_port         = 4105
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description     = "Canvas from the ALB only (public only when canvas_public adds the host rule)"
    from_port       = 3001
    to_port         = 3001
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description = "Canvas direct, operator IP only (the standing admin posture)"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "Dozzle log viewer, operator IP only"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  ingress {
    description = "SSH, operator IP only (deploys + ./unoverse key)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "data" {
  name        = "${var.name}-data"
  description = "Postgres + Redis: reachable from the app SG only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Postgres from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  ingress {
    description     = "Redis from app"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── VM: t3.xlarge, Ubuntu 22.04, 100GB gp3, Elastic IP ────────────────────────
# POC spec is 4 cores / 8 GB with the 8 GB fully allocated; 16 GB is the headroom
# choice at the same price as the exact-match c6i.xlarge (AWS_DEPLOYMENT.md).

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# The key pair, from the operator's own public key. AWS accepts an imported key, so nothing
# has to pre-exist in the account and no private key is ever downloaded or stored.
resource "aws_key_pair" "operator" {
  count      = var.operator_public_key != "" ? 1 : 0
  key_name   = "${var.name}-operator"
  public_key = var.operator_public_key
}

locals {
  key_name = var.operator_public_key != "" ? aws_key_pair.operator[0].key_name : var.ssh_key_name
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = local.s.instance
  key_name               = local.key_name
  vpc_security_group_ids = [aws_security_group.app.id]

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
  }

  tags = { Name = "${var.name}-app" }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"
  tags     = { Name = "${var.name}-app" }
}

# ── Postgres: RDS single-AZ, small on purpose ──────────────────────────────────
# The engine's ~19-usable-connection cap means a bigger instance buys nothing at
# POC (ONE_ENGINE.md). Retention is EXPLICIT: the API default is 1 day, and the
# rolling window self-purges — only manual/final snapshots persist and cost.

resource "random_password" "db" {
  length  = 32
  special = false
}

# Per-deployment credential-encryption key (SECURITY.md § Credential encryption at
# rest): the engine encrypts stored credentials with this. Generated here so no
# deployment ever runs on the committed default. Back it up WITH the database.
resource "random_password" "credential_key" {
  length  = 44 # ~32 bytes of entropy, base64-ish charset
  special = false
}

resource "aws_db_instance" "postgres" {
  identifier     = "${var.name}-pg"
  engine         = "postgres"
  engine_version = "16"
  instance_class = local.s.pg

  db_name  = "universe"
  username = "universe"
  password = random_password.db.result

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  vpc_security_group_ids = [aws_security_group.data.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name}-pg-final"
  # POC: no deletion_protection so teardown stays one command. Turn it on at graduation.
}

# ── Redis: ElastiCache single node, TLS + auth token ───────────────────────────
# Cache/queue state only — no backups by design (AWS_DEPLOYMENT.md).

resource "random_password" "redis" {
  length  = 32
  special = false
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.name}-redis"
  description          = "Gravity platform Redis (POC, single node)"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = local.s.redis
  num_cache_clusters   = 1

  security_group_ids         = [aws_security_group.data.id]
  transit_encryption_enabled = true
  auth_token                 = random_password.redis.result
  automatic_failover_enabled = false
  snapshot_retention_limit   = 0
}

# ── Cognito: user pool (Essentials) + pre-token Lambda ────────────────────────
# The Lambda is LOAD-BEARING: it puts email/roles/permissions on the ACCESS token
# (the platform's token contract, AUTH_TOKEN_FLOW.md). Roles come from Cognito
# groups. It lives in Terraform precisely so a pool rebuild cannot drop it — the
# documented Auth0 footgun, not repeated here.

data "archive_file" "pretoken" {
  type        = "zip"
  source_file = "${path.module}/pretoken/index.mjs"
  output_path = "${path.module}/pretoken/pretoken.zip"
}

resource "aws_iam_role" "pretoken" {
  name = "${var.name}-pretoken"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "pretoken_logs" {
  role       = aws_iam_role.pretoken.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM IS EVENTUALLY CONSISTENT, AND LAMBDA OUTRUNS IT. The role is created, Lambda is
# created two seconds later, and AWS answers "The role defined for the function cannot be
# assumed by Lambda" — the role is correct and simply not visible yet. Terraform's
# dependency graph is satisfied because the role exists; AWS's own propagation is not.
#
# Ten seconds is the usual advice and it costs ten seconds on a first apply only.
resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role.pretoken, aws_iam_role_policy_attachment.pretoken_logs]
  create_duration = "10s"
}

resource "aws_lambda_function" "pretoken" {
  depends_on       = [time_sleep.iam_propagation]
  function_name    = "${var.name}-pretoken"
  role             = aws_iam_role.pretoken.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.pretoken.output_path
  source_code_hash = data.archive_file.pretoken.output_base64sha256
}

resource "aws_lambda_permission" "cognito" {
  statement_id  = "AllowCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pretoken.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pool.arn
}

resource "aws_cognito_user_pool" "pool" {
  name = "${var.name}-users"

  # Essentials is the default plan for new pools and includes access-token
  # customization (verified 2026-07-28); stated explicitly so an AWS-side default
  # change can never silently downgrade the pool below what the Lambda needs.
  user_pool_tier = "ESSENTIALS"

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.pretoken.arn
      # V2_0 = "basic features + access token customization" — the whole point.
      lambda_version = "V2_0"
    }
  }

  # THE INVITATION HAS TO SAY WHERE TO GO. Cognito's default message is a username and a
  # temporary password and no address: the first administrator of a brand new universe
  # receives credentials for a login page they have never been told the name of, and the
  # hosted UI URL is buried in a terraform output they have no reason to read.
  #
  # The domain is built from the same random_id the domain resource uses, so this can name
  # the URL without depending on that resource and creating a cycle back to this pool.
  admin_create_user_config {
    allow_admin_create_user_only = true
    invite_message_template {
      # LINK TO THE APP, NOT TO COGNITO. The hosted sign-in page needs a client_id, and the
      # client is created FROM this pool — referencing it here is a dependency cycle. Canvas
      # is also simply the better destination: it redirects to Cognito itself, and the
      # administrator ends up where they were trying to go rather than on a login screen with
      # nowhere to land afterwards.
      # SMS IS REQUIRED EVEN WHEN ONLY EMAIL IS USED. Cognito validates the whole template:
      # omit sms_message and UpdateUserPool rejects it for an empty value that must be at
      # least six characters. It must contain {username} and {####} or the API refuses it.
      sms_message   = "Your ${var.name} universe: {username}, temporary password {####}"
      email_subject = "Your ${var.name} universe is ready"
      email_message = <<-MSG
        <p>Your universe is deployed, and this account administers it.</p>
        <p><b>Open it:</b> <a href="${local.canvas_entry}">${local.canvas_entry}</a></p>
        <p>Username: <b>{username}</b><br/>Temporary password: <b>{####}</b></p>
        <p>You will be asked to choose a new password the first time you sign in.</p>
      MSG
    }
  }
}

# Groups ARE the RBAC surface: membership becomes the `roles`/`permissions`
# claims via the Lambda. The two PLATFORM permissions are always provisioned
# (without them nobody can author or publish on this universe); everything else
# comes from var.roles — the deployment's own `noun:verb` role list, matched by
# node manifests' `requires.role` (DECLARATIVE_NODES.md §9.13).
locals {
  platform_roles = {
    "workflow:author"     = "May use the hosted workflow builder"
    "marketplace:publish" = "May publish items to this universe"
  }
  all_roles = merge(local.platform_roles, { for r in var.roles : r => "requires.role gate: ${r}" })
}

resource "aws_cognito_user_group" "roles" {
  for_each     = local.all_roles
  name         = each.key
  user_pool_id = aws_cognito_user_pool.pool.id
  description  = each.value
}

# The initial ADMIN — the first human in the universe. Without this, a fresh pool
# has no user who can author or publish. Cognito emails an invite with a temporary
# password (default message_action); first sign-in forces a password change. The
# admin sits in EVERY role group, so their token carries the full role set.
resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.pool.id
  username     = var.admin_email

  attributes = {
    email          = var.admin_email
    email_verified = "true"
  }
}

resource "aws_cognito_user_in_group" "admin" {
  for_each     = aws_cognito_user_group.roles
  user_pool_id = aws_cognito_user_pool.pool.id
  username     = aws_cognito_user.admin.username
  group_name   = each.value.name
}

resource "aws_cognito_user_pool_client" "spa" {
  name         = "${var.name}-spa"
  user_pool_id = aws_cognito_user_pool.pool.id

  # SPA/desktop client: public by definition, no secret (Studio/Canvas cannot keep one).
  generate_secret                      = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = var.oauth_callback_urls
  logout_urls                          = var.oauth_callback_urls
  supported_identity_providers         = ["COGNITO"]
}

# Cognito domains are GLOBALLY unique across all AWS accounts — a plain
# "gravity-poc-auth" will collide sooner or later; the random suffix makes the
# apply deterministic-safe. The full hosted-UI URL is an output either way.
resource "random_id" "auth_domain" {
  byte_length = 3
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "${var.name}-auth-${random_id.auth_domain.hex}"
  user_pool_id = aws_cognito_user_pool.pool.id
}

# ── Bedrock: one IAM user scoped to invoke ────────────────────────────────────
# Keys are stored as a platform `awsCredential` (aws-bedrock / aws-nova nodes).
# NOTE: the secret lands in Terraform state — acceptable at POC, noted in the doc.
# Model ACCESS is enabled in the console per model/region, outside Terraform.

resource "aws_iam_user" "bedrock" {
  name = "${var.name}-bedrock-invoke"
}

resource "aws_iam_user_policy" "bedrock" {
  name = "bedrock-invoke-only"
  user = aws_iam_user.bedrock.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:InvokeModelWithBidirectionalStream",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_access_key" "bedrock" {
  user = aws_iam_user.bedrock.name
}

# ── Native ingress (2026-07-29): ONE ALB, host-routed — the thing DO's LB can't
# do. api.<domain> → :4105 always; unoverse.<domain> → :3001 when canvas_public.
# Idle timeout 3600s: /stream (SSE) and /ws/gravity are long-lived; the ALB
# default of 60s severs them (INFRASTRUCTURE.md § Ingress).

resource "aws_acm_certificate" "public" {
  count                     = local.has_domain ? 1 : 0
  domain_name               = local.api_host
  subject_alternative_names = var.canvas_public ? ["canvas.${var.domain}"] : []
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation — automatic when the zone is in Route53, manual CNAME otherwise
# (the records to create are printed by the acm_validation_records output).
resource "aws_route53_record" "acm_validation" {
  for_each = local.dns_auto ? {
    for dvo in aws_acm_certificate.public[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = var.route53_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "public" {
  count                   = local.dns_auto ? 1 : 0
  certificate_arn         = aws_acm_certificate.public[0].arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

resource "aws_lb" "public" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids
  idle_timeout       = 3600
}

resource "aws_lb_target_group" "app" {
  name     = "${var.name}-app"
  port     = 4105
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path    = "/health"
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 4105
}

resource "aws_lb_target_group" "canvas" {
  count    = var.canvas_public ? 1 : 0
  name     = "${var.name}-canvas"
  port     = 3001
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_target_group_attachment" "canvas" {
  count            = var.canvas_public ? 1 : 0
  target_group_arn = aws_lb_target_group.canvas[0].arn
  target_id        = aws_instance.app.id
  port             = 3001
}

# :80 — with a domain it redirects to HTTPS; domainless it IS the front door
# (plain HTTP straight to the platform on the ALB's DNS name).
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.has_domain ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
  dynamic "default_action" {
    for_each = local.has_domain ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.app.arn
    }
  }
}

resource "aws_lb_listener" "https" {
  count             = local.has_domain ? 1 : 0
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.dns_auto ? aws_acm_certificate_validation.public[0].certificate_arn : aws_acm_certificate.public[0].arn

  # Default: the platform. An unknown Host lands here too, and the JWT gate is
  # in-app, so the ALB is never load-bearing for auth (the contract's rule 3).
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener_rule" "canvas" {
  count        = local.has_domain && var.canvas_public ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.canvas[0].arn
  }
  condition {
    host_header {
      values = ["canvas.${var.domain}"]
    }
  }
}

# Domainless canvas_public: no hostname to host-route by, so Canvas takes a
# second PORT instead — http://<alb-dns>:3001, the same shape as the DO ground.
resource "aws_lb_listener" "canvas_http" {
  count             = !local.has_domain && var.canvas_public ? 1 : 0
  load_balancer_arn = aws_lb.public.arn
  port              = 3001
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.canvas[0].arn
  }
}

# App DNS records (Route53 only — external DNS points these at the ALB by hand).
resource "aws_route53_record" "api" {
  count   = local.dns_auto ? 1 : 0
  zone_id = var.route53_zone_id
  name    = local.api_host
  type    = "A"

  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "unoverse" {
  count   = local.dns_auto && var.canvas_public ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "canvas.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}
