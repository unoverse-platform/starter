#!/usr/bin/env bash
# unoverse init, login, install-to-path, first-run check

# Install unoverse to PATH so it works globally
install_to_path() {
  local target="/usr/local/bin/unoverse"
  local script_path="$ROOT/unoverse"

  # Already installed and pointing to the right place
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$script_path" ]; then
    return
  fi

  # Already installed (different project) — skip
  if [ -f "$target" ] && [ ! -L "$target" ]; then
    return
  fi

  echo ""
  echo -e "  ${CYAN}${BOLD}Install unoverse command globally?${NC}"
  echo -e "  ${DIM}This lets you run ${NC}${BOLD}unoverse start${NC}${DIM} instead of ${NC}${BOLD}./unoverse start${NC}"
  echo ""
  read -r -p "  Install to /usr/local/bin/unoverse? [Y/n] " REPLY
  echo ""
  if [[ ! "$REPLY" =~ ^[Nn]$ ]]; then
    if ln -sf "$script_path" "$target" 2>/dev/null; then
      ok "Installed! You can now use ${BOLD}unoverse${NC} from anywhere in this project"
    else
      # Need sudo
      echo -e "  ${DIM}Requires admin access...${NC}"
      if sudo ln -sf "$script_path" "$target" 2>/dev/null; then
        ok "Installed! You can now use ${BOLD}unoverse${NC} from anywhere in this project"
      else
        warn "Could not install. Use ${BOLD}./unoverse${NC} instead"
      fi
    fi
  fi
}

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

  # Check Docker
  if ! command -v docker &>/dev/null; then
    fail "Docker is not installed"
    info "Install: https://docs.docker.com/get-docker/"
    exit 1
  fi

  if ! docker info &>/dev/null; then
    fail "Docker is not running. Please start Docker Desktop."
    exit 1
  fi
  ok "Docker is installed and running"

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

  # DOCR Token
  while true; do
    read -p "  DOCR Token (from your Unoverse admin): " DOCR_TOKEN
    if [[ "$DOCR_TOKEN" == dop_v1_* ]]; then
      break
    fi
    fail "Token should start with dop_v1_"
  done

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

  # Docker login
  echo ""
  echo -e "  Logging in to DigitalOcean Container Registry..."
  if echo "$DOCR_TOKEN" | docker login "$DOCR_REGISTRY" -u "$DOCR_TOKEN" --password-stdin &>/dev/null; then
    ok "Logged in to DOCR"
  else
    fail "DOCR login failed. Check your token"
    exit 1
  fi

  # Pull images
  cmd_pull

  # Install to PATH
  install_to_path

  # Done
  echo ""
  echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}${BOLD}  ✓ Setup Complete!${NC} ${DIM}($(timer_elapsed))${NC}"
  echo -e "  ${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${BOLD}Next steps:${NC}"
  echo ""
  echo -e "    ${GREEN}1.${NC} ${BOLD}unoverse dev${NC}     Set up dev environment and start the platform"
  echo -e "    ${GREEN}2.${NC} ${BOLD}unoverse open${NC}    Open Canvas in your browser"
  echo ""
  info "Run ${BOLD}unoverse doctor${NC} anytime to check health"
  echo ""
}
