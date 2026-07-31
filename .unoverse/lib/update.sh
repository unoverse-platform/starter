#!/usr/bin/env bash
# unoverse update + gravity update nodes

cmd_update() {
  echo ""
  echo -e "  ${BOLD}Updating Unoverse Platform${NC}"
  echo ""
  timer_start

  # ── Developer work is SAFE, by design ──────────────────────────────────────────
  # `update` refreshes the PLATFORM (its own tracked files) and NEVER touches a developer's
  # own work. Custom nodes live as UNTRACKED files (apps/unoverse/nodes/<yours>) — `git reset
  # --hard` ignores untracked files, and we no longer `git clean` them (see Step 1). So a
  # developer can create as many nodes as they want and `update` leaves them completely alone —
  # no stashing, no ceremony. The ONLY thing update overwrites is tracked PLATFORM files, so we
  # guard just those (a dev who edited framework code shouldn't lose it silently).
  # UNOVERSE_UPDATE_FORCE=1 overrides even that.
  if [ "${UNOVERSE_UPDATE_FORCE:-}" != "1" ] && [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
    fail "You have uncommitted edits to PLATFORM files that update would overwrite."
    echo ""
    echo -e "  ${DIM}Tracked files with local edits (your own untracked nodes are NOT affected):${NC}"
    git -C "$ROOT" status --short --untracked-files=no | sed 's/^/    /' | head -30
    echo ""
    info "Commit them:           git add -A && git commit -m 'wip'"
    info "Or overwrite on purpose: UNOVERSE_UPDATE_FORCE=1 unoverse update"
    echo ""
    exit 1
  fi

  # Step 1: Code — pull from customer's fork
  printf "  ${DIM}●${NC} Pulling latest code..."
  local git_ok=true
  local git_log
  git_log=$(mktemp)
  (
    cd "$ROOT"
    # Abort any stuck rebase/merge from a previous failed pull
    git rebase --abort >/dev/null 2>&1 || true
    git merge --abort >/dev/null 2>&1 || true
    # Reset generated files (e.g. marketplace templates from deploy.sh rebuild)
    # This is safe: .env, production.yml, node_modules, package-lock.json are gitignored
    git reset HEAD -- . >/dev/null 2>&1 || true
    git checkout -- . >/dev/null 2>&1 || true
    # Fetch latest from remote
    git fetch origin >/dev/null 2>&1 || true
    # Reset the PLATFORM's own tracked files to match remote exactly. This ignores UNTRACKED
    # files, so a developer's custom nodes (apps/unoverse/nodes/<yours>) are left alone.
    git reset --hard origin/$(git rev-parse --abbrev-ref HEAD) >/dev/null 2>&1 || true
    # NB: intentionally NO `git clean -fd` here. It DELETES untracked files, and a developer's
    # nodes are untracked — cleaning them was the "update deleted my node" bug. Marketplace
    # packages install into a gitignored dir, so clean never removed those anyway.
  ) || git_ok=false
  printf "\r\033[2K"
  if $git_ok; then
    ok "Code updated"
    rm -f "$git_log"
  else
    warn "Code update failed. Attempting recovery"
    local git_err
    git_err=$(cat "$git_log" 2>/dev/null | head -5)
    if [ -n "$git_err" ]; then
      echo -e "  ${DIM}Reason: $git_err${NC}"
    fi
    rm -f "$git_log"

    # Recovery: download latest CLI script from GitHub, then force-sync
    printf "  ${DIM}●${NC} Downloading latest update script..."
    local temp_update=$(mktemp)
    if curl -fsSL "https://raw.githubusercontent.com/unoverse-platform/starter/main/scripts/lib/update.sh" -o "$temp_update" 2>/dev/null; then
      cp "$temp_update" "$GRAVITY_LIB/update.sh"
      rm -f "$temp_update"
      printf "\r\033[2K"
      ok "Update script refreshed"

      # Now force-sync with the new script
      printf "  ${DIM}●${NC} Forcing sync with remote..."
      (
        cd "$ROOT"
        git fetch origin >/dev/null 2>&1 || true
        local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        git reset --hard origin/$branch >/dev/null 2>&1 || true
        # No `git clean -fd` — never delete a developer's untracked nodes (see Step 1).
      )
      printf "\r\033[2K"
      ok "Forced sync completed"
    else
      printf "\r\033[2K"
      fail "Recovery failed. Run: cd $ROOT && git reset --hard origin/main"
      exit 1
    fi
  fi

  # Step 2: Images — login to registry if DOCR_TOKEN is set
  local docr_token
  docr_token=$(grep "^DOCR_TOKEN=" "$ROOT/.env" 2>/dev/null | cut -d'=' -f2-)
  if [ -n "$docr_token" ]; then
    echo "$docr_token" | docker login registry.digitalocean.com -u "$docr_token" --password-stdin >/dev/null 2>&1 || true
  fi

  echo ""
  info "Pulling images..."
  echo ""

  local pull_start=$(date +%s)
  if docker compose -f "$ROOT/docker-compose.yml" pull; then
    local total_elapsed=$(( $(date +%s) - pull_start ))
    echo ""
    ok "Images pulled ${DIM}(${total_elapsed}s)${NC}"
  else
    echo ""
    fail "Image pull failed. Check network/registry and run ${BOLD}unoverse update${NC} again"
    exit 1
  fi

  # Step 3: Build packages (requires Node.js — installed by install.yml)
  local build_log
  build_log=$(mktemp)

  # Only run npm install if the dependency inputs changed or node_modules is
  # missing. Hash every package.json alongside the lockfile: a pulled range
  # bump (e.g. plugin-base ^1.2.0 → ^1.2.1) changes no lockfile — the starter
  # doesn't ship one — so hashing only package-lock.json would skip the install
  # that the bump exists to force.
  dep_inputs_hash() {
    cat "$ROOT/package-lock.json" "$ROOT"/package.json "$ROOT"/apps/unoverse/nodes/*/package.json 2>/dev/null \
      | { md5 -q 2>/dev/null || md5sum 2>/dev/null | cut -d' ' -f1; }
  }
  local need_install=false
  if [ ! -d "$ROOT/node_modules" ]; then
    need_install=true
  elif [ -f "$ROOT/.package-lock.hash" ]; then
    local old_hash=$(cat "$ROOT/.package-lock.hash" 2>/dev/null || echo "")
    local new_hash=$(dep_inputs_hash || echo "new")
    [ "$old_hash" != "$new_hash" ] && need_install=true
  else
    need_install=true
  fi

  (
    cd "$ROOT"
    if $need_install; then
      npm install --silent >/dev/null 2>&1 || true
      # Save hash for next run
      dep_inputs_hash > "$ROOT/.package-lock.hash" || true
    fi
    # Turbo handles build dependencies, no need to build plugin-base separately
    npm run build --workspaces --if-present >> "$build_log" 2>&1 || true
    # NOTE: component nodes are DEFINITION-BACKED (no generation): the universal
    # node package (nodes/components, shipped pre-built) synthesizes one node per
    # rx/components/* definition at boot. Component changes need only a restart —
    # a restart does that (start/dev also rebuild the package if dist is stale).
  ) &
  local build_pid=$!
  local build_start=$(date +%s)
  while kill -0 "$build_pid" 2>/dev/null || false; do
    local c="${spin:si%${#spin}:1}"
    si=$((si + 1))
    local elapsed=$(( $(date +%s) - build_start ))
    printf "\r  ${CYAN}%s${NC} Building packages... ${DIM}(%ds)${NC}  " "$c" "$elapsed"
    sleep 0.1
  done
  local build_exit=0
  wait "$build_pid" 2>/dev/null || build_exit=$?
  printf "\r\033[2K"
  if [ $build_exit -eq 0 ]; then
    ok "Packages built"
  else
    warn "Build completed with warnings. Check output:"
    cat "$build_log" | tail -20 | sed 's/^/    /'
  fi
  rm -f "$build_log"

  # Step 4: Restart — with spinner
  docker compose -f "$ROOT/docker-compose.yml" --env-file "$ROOT/.env" up -d --quiet-pull >/dev/null 2>&1 &
  local restart_pid=$!
  local restart_start=$(date +%s)
  while kill -0 "$restart_pid" 2>/dev/null || false; do
    local c="${spin:si%${#spin}:1}"
    si=$((si + 1))
    local elapsed=$(( $(date +%s) - restart_start ))
    printf "\r  ${CYAN}%s${NC} Restarting services... ${DIM}(%ds)${NC}  " "$c" "$elapsed"
    sleep 0.1
  done
  wait "$restart_pid" 2>/dev/null || true
  printf "\r\033[2K"

  # Verify services actually started (not stuck in Created)
  sleep 2
  local up_count=0 created_count=0 total_count=0
  # `grep -c` already PRINTS "0" (and exits 1) on no match, so `|| echo "0"` printed a
  # SECOND "0" → the var became "0\n0", which `[ -eq ]` rejects ("integer expression
  # expected"). Use `|| true` to swallow grep's exit code without emitting a stray line.
  total_count=$(docker compose -f "$ROOT/docker-compose.yml" ps -a --format "{{.Name}}" 2>/dev/null | grep -c . || true)
  up_count=$(docker compose -f "$ROOT/docker-compose.yml" ps -a --format "{{.Status}}" 2>/dev/null | grep -ci "up\|running" || true)
  created_count=$(docker compose -f "$ROOT/docker-compose.yml" ps -a --format "{{.Status}}" 2>/dev/null | grep -ci "created" || true)

  if [ "${up_count:-0}" -eq "${total_count:-0}" ] && [ "${total_count:-0}" -gt 0 ]; then
    ok "All $up_count services running"
  elif [ "${created_count:-0}" -gt 0 ]; then
    warn "$up_count/$total_count services running: $created_count stuck in Created state"
    info "Run ${BOLD}unoverse check${NC} to diagnose"
  elif [ "${up_count:-0}" -gt 0 ]; then
    warn "$up_count/$total_count services running"
    info "Run ${BOLD}unoverse status${NC} to check"
  else
    fail "No services running after restart"
    info "Run ${BOLD}unoverse check${NC} to diagnose"
  fi

  # Summary. Re-source the SHARED box helper first: `update` pulled fresh scripts a
  # moment ago, but the copy loaded at startup is stale — reload so the summary reflects
  # what we just pulled (fixes the "branded box / Studio line shows one run late" bug).
  source "$GRAVITY_LIB/common.sh" 2>/dev/null || true
  echo ""
  echo -e "  ${GREEN}${BOLD}Done${NC} ${DIM}in $(timer_elapsed)${NC}"
  echo ""
  print_access_urls
  echo ""
}

cmd_update_nodes() {
  echo ""
  echo -e "  ${BOLD}Updating Nodes${NC}"
  echo ""
  timer_start

  # Step 1: Dependencies
  printf "  ${DIM}●${NC} Installing dependencies..."
  (cd "$ROOT" && npm install --silent >/dev/null 2>&1) || true
  printf "\r\033[2K"
  ok "Dependencies installed"

  # Step 2: Build
  printf "  ${DIM}●${NC} Building packages..."
  (cd "$ROOT" && npm run build -w @unoverse-platform/plugin-base >/dev/null 2>&1) || true
  local build_output
  build_output=$(cd "$ROOT" && npm run build --workspaces --if-present 2>&1) || true
  local pkg_count
  pkg_count=$(echo "$build_output" | grep -c '> .* build' || echo "0")
  printf "\r\033[2K"
  ok "${pkg_count} packages built"

  # Step 3 (retired): component nodes are DEFINITION-BACKED — no generation step.
  # They synthesize from rx/components at boot; the universal package is built
  # in-container on start/dev (and by `unoverse deploy packages` on the server).

  # Step 4: Restart
  printf "  ${DIM}●${NC} Restarting unoverse..."
  docker compose -f "$ROOT/docker-compose.yml" restart unoverse >/dev/null 2>&1 || true
  printf "\r\033[2K"
  ok "Node-service restarted"

  # Summary
  echo ""
  echo -e "  ${GREEN}${BOLD}Done${NC} ${DIM}in $(timer_elapsed)${NC}"
  echo ""
}

# ── cmd_pull — INTERNAL helper (init + update use it). Not a user command since 2026-07-28. ──

cmd_pull() {
  echo ""
  read -r -p "  Pull platform images now? (~1.2GB first time) [Y/n] " REPLY
  echo ""
  if [[ "$REPLY" =~ ^[Nn]$ ]]; then
    info "Skipped. Run ${BOLD}unoverse start${NC} later."
    return
  fi

  local IMAGES=(
    "registry.digitalocean.com/gravity-repo/canvas:latest"
    "registry.digitalocean.com/gravity-repo/umap:latest"
    "registry.digitalocean.com/gravity-repo/unoverse:latest"
    "registry.digitalocean.com/gravity-repo/memory:latest"
  )

  local total=${#IMAGES[@]}
  local count=0
  local failed=0

  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

  echo ""
  for img in "${IMAGES[@]}"; do
    count=$((count + 1))
    local short="${img##*/}"          # gravity-server:latest
    short="${short%%:*}"              # gravity-server

    # Start pull in background
    docker pull "$img" &>/dev/null &
    local pid=$!

    # Animate spinner while pulling
    local i=0
    while kill -0 "$pid" 2>/dev/null || false; do
      local c="${spin:i%${#spin}:1}"
      i=$((i + 1))
      printf "\r  ${DIM}[%d/%d]${NC} ${CYAN}%s${NC} Pulling ${BOLD}%s${NC} " "$count" "$total" "$c" "$short"
      sleep 0.1
    done

    # Check result
    local pull_exit=0
    wait "$pid" 2>/dev/null || pull_exit=$?
    if [ $pull_exit -eq 0 ]; then
      printf "\r  ${DIM}[%d/%d]${NC} ${GREEN}✓${NC} Pulling ${BOLD}%s${NC} \n" "$count" "$total" "$short"
    else
      printf "\r  ${DIM}[%d/%d]${NC} ${RED}✗${NC} Pulling ${BOLD}%s${NC} \n" "$count" "$total" "$short"
      failed=$((failed + 1))
    fi
  done
  echo ""

  # Count how many gravity images we have now
  local pulled
  pulled=$(docker images -a --format "{{.Repository}}" | grep -c "gravity-repo" || true)
  pulled=$(echo "$pulled" | tr -d '[:space:]')
  pulled=${pulled:-0}

  echo ""
  if [ "$pulled" -ge 5 ]; then
    ok "All $pulled images pulled"
  elif [ "$pulled" -gt 0 ]; then
    warn "$pulled images pulled (some may need retry)"
    info "Run ${BOLD}unoverse pull${NC} to retry"
  else
    fail "No images pulled. Check your DOCR token and network"
    exit 1
  fi
}
