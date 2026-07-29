#!/usr/bin/env bash
# unoverse doctor

cmd_doctor() {

  banner "Unoverse Doctor"
  echo ""

  local issues=0

  # Docker
  if command -v docker &>/dev/null && docker info &>/dev/null; then
    ok "Docker is installed and running"
  else
    fail "Docker is not installed or not running"
    issues=$((issues + 1))
  fi

  # Apple Silicon
  if [ "$(uname -m)" = "arm64" ]; then
    ok "Apple Silicon detected: multi-arch images will run natively"
  fi

  # Project root
  if [ -f "$ROOT/docker-compose.yml" ]; then
    ok "Project root: $ROOT"
  else
    fail "No docker-compose.yml found"
    issues=$((issues + 1))
    print_summary $issues
    return
  fi

  # Docker file sharing
  if ! check_docker_file_sharing; then
    issues=$((issues + 1))
  fi

  # .env
  if [ -f "$ROOT/.env" ]; then
    ok ".env file exists"
  else
    fail ".env file missing. Run ${BOLD}unoverse init${NC}"
    issues=$((issues + 1))
    print_summary $issues
    return
  fi

  # Required env vars. (API_URL is intentionally NOT required: the server/engine
  # never read it, the canvas bakes its own at build via VITE_API_URL, and the only
  # runtime user — pdf-render — treats it as an optional fallback.)
  local required_vars="DATABASE_URL REDIS_HOST AUTH_ISSUER AUTH_CLIENT_ID AUTH_AUDIENCE"
  local placeholders="your- user:password host:5432"

  for var in $required_vars; do
    local val
    val=$(grep "^${var}=" "$ROOT/.env" 2>/dev/null | cut -d'=' -f2-)
    if [ -z "$val" ]; then
      fail "$var is not set"
      issues=$((issues + 1))
    else
      local is_placeholder=false
      for p in $placeholders; do
        if echo "$val" | grep -q "$p"; then
          is_placeholder=true
          break
        fi
      done
      if $is_placeholder; then
        warn "$var looks like a placeholder: ${DIM}$val${NC}"
        issues=$((issues + 1))
      else
        local display="${val:0:40}"
        [ ${#val} -gt 40 ] && display="${display}..."
        ok "$var = ${DIM}$display${NC}"
      fi
    fi
  done

  # DOCR login
  local docker_config="$HOME/.docker/config.json"
  if [ -f "$docker_config" ] && grep -q "$DOCR_REGISTRY" "$docker_config" 2>/dev/null; then
    ok "Logged in to DigitalOcean Container Registry"
  else
    fail "Not logged in to DOCR. Run ${BOLD}unoverse init${NC}"
    issues=$((issues + 1))
  fi

  # Images
  local image_count
  image_count=$(docker images -a --format "{{.Repository}}" 2>/dev/null | grep -c "gravity-repo" || true)
  image_count=${image_count:-0}
  image_count=$(echo "$image_count" | tr -d '[:space:]')
  image_count=${image_count:-0}
  if [ "$image_count" -ge 5 ]; then
    ok "$image_count images available"
  else
    warn "Images not pulled yet. Run ${BOLD}unoverse pull${NC}"
    issues=$((issues + 1))
  fi

  # Services running — use -a to catch Created containers
  local running_output
  running_output=$(docker compose -f "$ROOT/docker-compose.yml" ps -a --format "{{.Name}}\t{{.Status}}" 2>/dev/null) || true
  if [ -n "$running_output" ]; then
    local total running created_doc
    total=$(echo "$running_output" | wc -l | tr -d '[:space:]')
    running=$(echo "$running_output" | grep -ci "up" || true)
    running=$(echo "$running" | tr -d '[:space:]')
    running=${running:-0}
    created_doc=$(echo "$running_output" | grep -ci "created" || true)
    created_doc=$(echo "$created_doc" | tr -d '[:space:]')
    created_doc=${created_doc:-0}
    if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
      ok "All $running services running"
    elif [ "$created_doc" -gt 0 ]; then
      fail "$created_doc services stuck in Created state (never started)"
      info "This usually means Docker cannot mount the project volume"
      issues=$((issues + 1))
    else
      warn "$running/$total services running"
      issues=$((issues + 1))
    fi
  else
    info "No services found (run ${BOLD}unoverse start${NC})"
  fi

  # Memory service health
  local mem_code
  mem_code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:4104/health" 2>/dev/null)
  if [ "$mem_code" = "200" ]; then
    ok "Memory service reachable ${DIM}:4104${NC}"
  else
    fail "Memory service not reachable ${DIM}:4104 → $mem_code${NC}"
    info "Check memory container logs: ${BOLD}unoverse logs memory${NC}"
    issues=$((issues + 1))
  fi

  # Memory API proxy in canvas nginx
  local proxy_code
  proxy_code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:3001/mem-api/health" 2>/dev/null)
  if [ "$proxy_code" = "200" ]; then
    ok "Canvas → memory proxy working ${DIM}/mem-api${NC}"
  else
    warn "Canvas /mem-api proxy not working ${DIM}→ $proxy_code${NC}"
    info "Rebuild canvas image to pick up nginx proxy config"
    issues=$((issues + 1))
  fi

  # Redis
  local redis_host
  redis_host=$(grep "^REDIS_HOST=" "$ROOT/.env" 2>/dev/null | cut -d'=' -f2-)
  if [ "$redis_host" = "host.docker.internal" ] || [ "$redis_host" = "localhost" ]; then
    if docker ps --format "{{.Names}}" 2>/dev/null | grep -qi redis; then
      ok "Local Redis container running"
    else
      warn "No local Redis container found"
      info "Start one: docker run -d --name gravity-redis -p 6379:6379 redis:7-alpine"
      issues=$((issues + 1))
    fi
  elif [ -n "$redis_host" ]; then
    info "Redis: using external host ${DIM}$redis_host${NC}"
  fi

  print_summary $issues
}

print_summary() {
  local issues=$1
  echo ""
  if [ "$issues" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Everything looks good!${NC}"
  else
    echo -e "  ${YELLOW}${BOLD}⚠ $issues issue$( [ "$issues" -gt 1 ] && echo 's') found${NC}"
  fi
  echo ""
}

# Studio mode diagnostics: Node, dependencies, and the folders Studio reads.

