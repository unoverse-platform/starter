#!/usr/bin/env bash
# unoverse check

cmd_check() {
  echo ""
  echo -e "  ${BOLD}Unoverse Platform Health Check${NC}"
  echo ""
  local pass=0 total=0

  # 1. Services
  for svc in unoverse canvas umap memory; do
    total=$((total + 1))
    local status
    status=$(docker compose -f "$ROOT/docker-compose.yml" ps --format '{{.Status}}' "$svc" 2>/dev/null | head -1)
    if echo "$status" | grep -qi "up"; then
      ok "$svc"
      pass=$((pass + 1))
    elif echo "$status" | grep -qi "created"; then
      fail "$svc ${DIM}(stuck in Created, the container never started)${NC}"
    elif [ -z "$status" ]; then
      fail "$svc ${DIM}(no container found)${NC}"
    else
      fail "$svc ${DIM}($status)${NC}"
    fi
  done
  echo ""

  # 2. Health endpoints
  for endpoint in 4105:unoverse 4101:engine 5001:umap 4104:memory; do
    local port="${endpoint%%:*}" name="${endpoint##*:}"
    total=$((total + 1))
    local code
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$port/health" 2>/dev/null)
    if [ "$code" = "200" ]; then
      ok "$name health ${DIM}:$port${NC}"
      pass=$((pass + 1))
    else
      fail "$name health ${DIM}:$port → $code${NC}"
    fi
  done
  echo ""

  # 3. Packages built
  local built=0 pkg_total=0
  for pkg in "$ROOT"/packages/*/; do
    [ -f "$pkg/package.json" ] || continue
    local name
    name=$(basename "$pkg")
    case "$name" in marketplace|gravity-client|plugin-base|skills|prompt-blocks) continue;; esac
    pkg_total=$((pkg_total + 1))
    if [ -f "$pkg/dist/index.js" ]; then
      built=$((built + 1))
    else
      fail "$name ${DIM}(missing dist/index.js)${NC}"
    fi
  done
  total=$((total + 1))
  if [ "$built" -eq "$pkg_total" ]; then
    ok "$built/$pkg_total packages built"
    pass=$((pass + 1))
  else
    fail "$built/$pkg_total packages built"
  fi

  # 4. Unoverse node catalog
  total=$((total + 1))
  local plugin_count
  # Catalog lives on unoverse; :4106 is Docker-internal and :4105 /plugins is JWT-gated,
  # so count nodes from inside the container (node:20-slim has no curl → use node fetch).
  plugin_count=$(docker compose -f "$ROOT/docker-compose.yml" exec -T unoverse node -e "fetch('http://127.0.0.1:4106/nodes').then(r=>r.json()).then(d=>console.log((d.nodes||[]).length)).catch(()=>console.log(0))" 2>/dev/null | tr -d ' \r')
  if [ "$plugin_count" -gt "0" ]; then
    ok "$plugin_count nodes loaded"
    pass=$((pass + 1))
  else
    fail "0 nodes loaded ${DIM}(check unoverse logs)${NC}"
  fi

  # 5. Canvas
  total=$((total + 1))
  local canvas_code
  canvas_code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:3001" 2>/dev/null)
  if [ "$canvas_code" = "200" ]; then
    ok "Canvas ${DIM}http://localhost:3001${NC}"
    pass=$((pass + 1))
  else
    fail "Canvas ${DIM}http://localhost:3001 → $canvas_code${NC}"
  fi

  # Summary
  echo ""
  if [ "$pass" -eq "$total" ]; then
    echo -e "  ${GREEN}${BOLD}All $total checks passed${NC}"
  else
    echo -e "  ${YELLOW}${BOLD}$pass/$total checks passed${NC}"
  fi
  echo ""
}
