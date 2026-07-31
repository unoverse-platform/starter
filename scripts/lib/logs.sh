#!/usr/bin/env bash
# unoverse logs

cmd_logs() {
  local service="$1"
  if [ -n "$service" ]; then
    banner "Logs: $service"
    info "Press Ctrl+C to stop"
    echo ""
    docker compose -f "$ROOT/docker-compose.yml" logs -f --tail 100 "$service"
  else
    banner "Log Viewer (Dozzle)"
    # No service → open the Dozzle web log viewer. It runs by default now, but
    # start it as a fallback in case it was manually stopped.
    if ! docker compose -f "$ROOT/docker-compose.yml" ps --status running dozzle 2>/dev/null | grep -q dozzle; then
      info "Starting the Dozzle log viewer..."
      docker compose -f "$ROOT/docker-compose.yml" up -d dozzle >/dev/null 2>&1 || true
    fi
    info "Tip: ${BOLD}unoverse logs <service>${NC} to stream one service in the terminal"
    echo ""
    cmd_open logs
  fi
}
