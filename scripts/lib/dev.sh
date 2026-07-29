#!/usr/bin/env bash
# unoverse dev

cmd_dev() {
  banner "Unoverse Dev Setup"
  local dev_cold_start=0

  # Check node/npm
  if ! command -v node &>/dev/null; then
    fail "Node.js is not installed"
    info "Install: https://nodejs.org/ or nvm install 20"
    exit 1
  fi
  ok "Node.js $(node --version)"

  if ! command -v npm &>/dev/null; then
    fail "npm is not installed"
    exit 1
  fi
  ok "npm $(npm --version)"

  # Ensure platform is running (check for actually running containers, not just created)
  local running_count
  running_count=$(docker compose -f "$ROOT/docker-compose.yml" ps --format "{{.Name}}" --filter "status=running" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$running_count" -eq 0 ] 2>/dev/null; then
    warn "Platform is not running. Starting it first..."
    cmd_start
    dev_cold_start=1   # cmd_start already compiled the component nodes
  else
    ok "Platform is running ($running_count services)"
  fi

  # Re-check after potential cmd_start — bail if still not running
  running_count=$(docker compose -f "$ROOT/docker-compose.yml" ps --format "{{.Name}}" --filter "status=running" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$running_count" -eq 0 ] 2>/dev/null; then
    fail "Platform failed to start. Run ${BOLD}unoverse doctor${NC} to diagnose"
    exit 1
  fi

  # Install workspace dependencies
  echo ""
  echo "  Installing workspace dependencies..."
  (cd "$ROOT" && npm install --silent 2>/dev/null)
  ok "Dependencies installed"

  # Build all packages (plugin-base first as it's a dependency for others)
  echo ""
  echo "  Building packages..."
  (cd "$ROOT" && npm run build -w @unoverse-platform/plugin-base 2>/dev/null) || warn "plugin-base build failed"
  local dev_build_output
  dev_build_output=$(cd "$ROOT" && npm run build --workspaces --if-present 2>&1) || warn "some packages failed to build"
  local dev_pkg_count
  dev_pkg_count=$(echo "$dev_build_output" | grep -c '> .* build$' || echo "0")
  ok "Packages built ${DIM}(${dev_pkg_count} packages)${NC}"

  # Compile component (design) nodes + restart unoverse to pick up the built packages.
  # On a cold start, cmd_start already compiled the component nodes → just restart.
  # Otherwise run build_component_nodes, which tsc-builds them AND restarts unoverse
  # (so it also loads the workspace packages we just built).
  echo ""
  local ns_status
  ns_status=$(docker compose -f "$ROOT/docker-compose.yml" ps --format '{{.Status}}' unoverse 2>/dev/null | head -1)
  if ! echo "$ns_status" | grep -qi "up"; then
    warn "unoverse is not running (status: ${ns_status:-unknown}). Skipping restart"
    info "Run ${BOLD}unoverse doctor${NC} to diagnose"
  elif [ "$dev_cold_start" = "1" ]; then
    echo "  Restarting unoverse..."
    docker compose -f "$ROOT/docker-compose.yml" restart unoverse 2>/dev/null || true
    ok "unoverse restarted"
  else
    build_component_nodes
  fi

  # Final status check
  running_count=$(docker compose -f "$ROOT/docker-compose.yml" ps --format "{{.Name}}" --filter "status=running" 2>/dev/null | wc -l | tr -d ' ')
  echo ""
  banner "Dev Environment Ready"
  echo ""
  if [ "$running_count" -gt 0 ]; then
    ok "Platform running ($running_count services): Canvas: http://localhost:3001"
  else
    warn "Platform may not be fully running. Check ${BOLD}unoverse status${NC}"
  fi
  ok "Custom code in ${BOLD}packages/${NC} is mounted into unoverse"
  echo ""
  info "After making changes:"
  info "  ./unoverse build                              # Build all + restart"
  info "  ./unoverse build @unoverse-platform/my-node    # Build one package + restart"
  echo ""
}
