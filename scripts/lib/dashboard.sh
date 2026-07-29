#!/usr/bin/env bash
# unoverse dashboard (default command when no args)

cmd_dashboard() {
  echo ""
  echo -e "  ${BOLD}${CYAN}⬡ Unoverse Platform${NC} ${DIM}v${GRAVITY_VERSION}${NC}"
  echo -e "  ${DIM}─────────────────────────────────${NC}"

  # Check if .env exists
  if [ ! -f "$ROOT/.env" ]; then
    echo ""
    echo -e "  ${YELLOW}${BOLD}First time?${NC} Run ${GREEN}${BOLD}./unoverse init${NC} to get started."
    echo ""
    return
  fi

  # Quick status — use -a to see Created containers too
  local ps
  ps=$(docker compose -f "$ROOT/docker-compose.yml" ps -a --format "{{.Name}}\t{{.Status}}" 2>/dev/null) || true

  if [ -n "$ps" ]; then
    local total running created
    total=$(echo "$ps" | wc -l | tr -d ' ')
    running=$(echo "$ps" | grep -ci "up" || echo "0")
    created=$(echo "$ps" | grep -ci "created" || echo "0")

    echo ""
    if [ "$running" -eq "$total" ] && [ "$total" -gt 0 ]; then
      echo -e "  ${GREEN}●${NC} ${BOLD}Platform running${NC} ${DIM}($running services)${NC}"
      echo ""
      print_access_urls
    elif [ "$created" -gt 0 ] && [ "$running" -eq 0 ]; then
      echo -e "  ${RED}●${NC} ${BOLD}$total containers stuck in Created state${NC}"
      echo ""
      echo -e "  Containers were created but never started."
      echo -e "  Run ${GREEN}${BOLD}unoverse doctor${NC} to diagnose"
    elif [ "$running" -gt 0 ]; then
      echo -e "  ${YELLOW}●${NC} ${BOLD}$running/$total services up${NC}"
      echo ""
      print_access_urls
    else
      echo -e "  ${RED}●${NC} ${BOLD}Platform not running${NC} ${DIM}($total containers stopped)${NC}"
      echo ""
      echo -e "  Run ${GREEN}${BOLD}./unoverse start${NC} to launch"
    fi
  else
    echo ""
    echo -e "  ${DIM}●${NC} ${BOLD}Platform stopped${NC}"
    echo ""
    echo -e "  Run ${GREEN}${BOLD}./unoverse start${NC} to launch"
  fi

  echo ""
  echo -e "  ${DIM}Run ${NC}${BOLD}./unoverse help${NC}${DIM} for all commands${NC}"
  echo ""
}

# ── unoverse open — browser shortcut (merged from open.sh 2026-07-28) ──

cmd_open() {
  local target="${1:-canvas}"
  local url

  case "$target" in
    canvas)        url="http://localhost:3001" ;;
    api)           url="http://localhost:4105" ;;
    logs|dozzle)   url="http://localhost:8080" ;;
    *)
      fail "Unknown target: $target"
      info "Options: canvas, api, logs"
      return
      ;;
  esac

  ok "Opening $target → ${UNDERLINE}$url${NC}"

  # Cross-platform open
  if command -v open &>/dev/null; then
    open "$url"
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$url"
  else
    info "Open in your browser: $url"
  fi
}
