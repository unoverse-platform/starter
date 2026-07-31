#!/usr/bin/env bash
# unoverse init, login, install-to-path, first-run check

# install_to_path REMOVED 2026-07-31. The global command is the npm package `unoverse`
# (`npm i -g unoverse`); symlinking a per-project bash script into /usr/local/bin was the
# second CLI we set out to delete.

# First-run detection
check_first_run() {
  if [ ! -f "$ROOT/.env" ]; then
    echo ""
    echo -e "  ${YELLOW}${BOLD}Welcome to Unoverse!${NC}"
    echo ""
    echo -e "  Looks like this is your first time. Let's get you set up."
    echo -e "  You'll need credentials from your Unoverse admin."
    echo ""
    read -r -p "  Ready to start setup? [Y/n] " REPLY
    echo ""
    if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
      cmd_init
    else
      echo ""
      info "Run ${BOLD}unoverse init${NC} when you're ready."
      echo ""
    fi
    exit 0
  fi
}

cmd_login() {
  # Check if already logged in
  local docker_config="$HOME/.docker/config.json"
  if [ -f "$docker_config" ]; then
    if grep -q "$DOCR_REGISTRY" "$docker_config" 2>/dev/null; then
      ok "Already logged in to DOCR"
      return
    fi
  fi

  read -p "  DOCR Token: " TOKEN
  if echo "$TOKEN" | docker login "$DOCR_REGISTRY" -u "$TOKEN" --password-stdin &>/dev/null; then
    ok "Logged in to DOCR"
  else
    fail "Login failed"
    exit 1
  fi
}

cmd_init() {
  echo ""
  echo -e "  ${BOLD}${CYAN}⬡ Unoverse Setup${NC}"
  echo -e "  ${DIM}─────────────────────────────────${NC}"
  echo ""

  # (The studio/platform mode interview was removed 2026-07-28 — Studio is a
  # separate app, and this CLI only sets up the platform.)
  timer_start

  # DOCKER IS NEEDED TO START, NOT TO CONFIGURE. This used to exit here, which threw
  # away a scaffold and a validated token because Docker Desktop happened to be closed.
  # Writing .env needs nothing running, so record the state and carry on; the steps that
  # genuinely need a daemon skip themselves, and `start` is where it becomes an error.
  DOCKER_OK=0
  if ! command -v docker &>/dev/null; then
    warn "Docker is not installed. Configuration will finish; install it before ${BOLD}unoverse start${NC}"
    info "Install: https://docs.docker.com/get-docker/"
  elif ! docker info &>/dev/null; then
    warn "Docker is not running. Configuration will finish; start Docker Desktop before ${BOLD}unoverse start${NC}"
  else
    DOCKER_OK=1
    ok "Docker is installed and running"
  fi

  # Apple Silicon check
  if [ "$(uname -m)" = "arm64" ]; then
    ok "Apple Silicon detected: multi-arch images will run natively"
    echo ""
  fi

  # Check for existing .env
  if [ -f "$ROOT/.env" ]; then
    echo ""
    read -r -p "  .env already exists. Overwrite? [y/N] " REPLY
    echo ""
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
      info "Keeping existing .env"
      cmd_login
      cmd_pull
      return
    fi
  fi

  echo ""
  echo -e "  ${BOLD}Configure your environment:${NC}"
  echo -e "  ${DIM}(Press Enter to use defaults)${NC}"
  echo ""

  # DOCR Token. `unoverse create` has already asked for this and VALIDATED it against
  # the registry, so it hands it over rather than making you type the same credential
  # twice minutes apart. Typed here only when init is run on its own.
  if [ -n "${UNOVERSE_DOCR_TOKEN:-}" ]; then
    DOCR_TOKEN="$UNOVERSE_DOCR_TOKEN"
    ok "Registry token carried over from create"
  else
    while true; do
      read -p "  DOCR Token (from your Unoverse admin): " DOCR_TOKEN
      if [[ "$DOCR_TOKEN" == dop_v1_* ]]; then
        break
      fi
      fail "Token should start with dop_v1_"
    done
  fi

  # Database (required — from admin)
  while true; do
    read -p "  DATABASE_URL (from your admin): " DATABASE_URL
    if [ -n "$DATABASE_URL" ] && [[ "$DATABASE_URL" != *"user:password"* ]]; then
      break
    fi
    fail "DATABASE_URL is required. Get it from your Unoverse admin"
  done

  # Auto-add SSL params if missing
  if [[ "$DATABASE_URL" != *"sslmode="* ]] && [[ "$DATABASE_URL" != *"ssl="* ]]; then
    local sep="?"
    [[ "$DATABASE_URL" == *"?"* ]] && sep="&"
    if [[ "$DATABASE_URL" == *"localhost"* ]] || \
       [[ "$DATABASE_URL" == *"127.0.0.1"* ]] || \
       [[ "$DATABASE_URL" == *"host.docker.internal"* ]]; then
      DATABASE_URL="${DATABASE_URL}${sep}sslmode=disable"
      ok "Local database detected. Added sslmode=disable"
    else
      DATABASE_URL="${DATABASE_URL}${sep}sslmode=require"
      ok "Managed database detected. Added sslmode=require"
    fi
  fi

  # Redis
  read -p "  REDIS_HOST [host.docker.internal]: " REDIS_HOST
  REDIS_HOST="${REDIS_HOST:-host.docker.internal}"

  read -p "  REDIS_PORT [6379]: " REDIS_PORT
  REDIS_PORT="${REDIS_PORT:-6379}"

  read -p "  REDIS_PASSWORD (blank for none): " REDIS_PASSWORD

  read -p "  REDIS_TLS [false]: " REDIS_TLS
  REDIS_TLS="${REDIS_TLS:-false}"

  # Auth (required — from admin)
  while true; do
    read -p "  AUTH_ISSUER (e.g. https://your-tenant.auth0.com): " AUTH_ISSUER
    if [ -n "$AUTH_ISSUER" ] && [[ "$AUTH_ISSUER" != *"your-tenant"* ]]; then
      break
    fi
    fail "AUTH_ISSUER is required. Get it from your Unoverse admin"
  done

  while true; do
    read -p "  AUTH_CLIENT_ID: " AUTH_CLIENT_ID
    if [ -n "$AUTH_CLIENT_ID" ] && [[ "$AUTH_CLIENT_ID" != *"your-"* ]]; then
      break
    fi
    fail "AUTH_CLIENT_ID is required. Get it from your Unoverse admin"
  done

  read -p "  AUTH_AUDIENCE [gravity-api]: " AUTH_AUDIENCE
  AUTH_AUDIENCE="${AUTH_AUDIENCE:-gravity-api}"

  # API URL
  read -p "  API_URL [http://localhost:4105]: " API_URL
  API_URL="${API_URL:-http://localhost:4105}"

  # OpenAI (for Memory Server)
  read -p "  OPENAI_API_KEY (for Memory Server, blank to skip): " OPENAI_API_KEY

  # Write .env
  cat > "$ROOT/.env" << ENVEOF
# Generated by unoverse init
DOCR_TOKEN=${DOCR_TOKEN}
DATABASE_URL=${DATABASE_URL}
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_TLS=${REDIS_TLS}
REDIS_NAMESPACE=gravity
AUTH_ISSUER=${AUTH_ISSUER}
AUTH_CLIENT_ID=${AUTH_CLIENT_ID}
AUTH_AUDIENCE=${AUTH_AUDIENCE}
API_URL=${API_URL}
OPENAI_API_KEY=${OPENAI_API_KEY}
DOMAIN=
ENVEOF

  ok ".env created"

  # Registry login and the image pull both need a daemon. Without one the token is
  # already written to .env, so `unoverse start` does this on its first run.
  if [ "$DOCKER_OK" = "1" ]; then
    echo ""
    echo -e "  Logging in to DigitalOcean Container Registry..."
    if echo "$DOCR_TOKEN" | docker login "$DOCR_REGISTRY" -u "$DOCR_TOKEN" --password-stdin &>/dev/null; then
      ok "Logged in to DOCR"
    else
      fail "DOCR login failed. Check your token"
      exit 1
    fi
    cmd_pull
  else
    echo ""
    info "Skipped the registry login and image pull. ${BOLD}unoverse start${NC} does both once Docker is up"
  fi

  # Install to PATH
  
  # Done
  echo ""
  echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}  ✓ Setup Complete!${NC} ${DIM}($(timer_elapsed))${NC}"
  echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  # MIGRATIONS RUN HERE, so `db-setup` is not a command anyone has to know about. Deploy
  # already ran them on the server (playbooks/db-setup.yml); this is the local half.
  # A database that is not reachable yet is not a failed setup — .env is written and
  # correct, so say so and move on rather than unwinding everything.
  echo ""
  if grep -q '^DATABASE_URL=' "$ROOT/.env" 2>/dev/null; then
    if cmd_db_setup; then
      ok "Database schema is up to date"
    else
      warn "Could not reach the database yet. Run ${BOLD}unoverse check${NC} once it is up"
    fi
  fi

  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo ""
  if [ "$DOCKER_OK" = "1" ]; then
    echo -e "    ${GREEN}unoverse start${NC}     Start the platform"
  else
    echo -e "    ${DIM}1.${NC} Start Docker Desktop"
    echo -e "    ${DIM}2.${NC} ${GREEN}unoverse start${NC}"
  fi
  echo -e "    ${GREEN}unoverse where${NC}     Its addresses, once it is up"
  echo ""
  info "Run ${BOLD}unoverse check${NC} anytime to see if it is healthy"
  echo ""
}
