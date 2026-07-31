#!/usr/bin/env bash
# unoverse stop

cmd_stop() {
  banner "Stopping Unoverse Platform"
  timer_start
  docker compose -f "$ROOT/docker-compose.yml" down --remove-orphans >/dev/null 2>&1
  echo ""
  ok "Platform stopped ${DIM}($(timer_elapsed))${NC}"
  echo ""
}
