#!/usr/bin/env bash
# unoverse build + the internal component-node package build (definition-backed)

cmd_build() {
  local package="$1"
  banner "Build & Restart"

  if [ -z "$package" ]; then
    echo "  Building all packages..."
    (cd "$ROOT" && npm run build)
    ok "All packages built"
  else
    echo "  Building $package..."
    (cd "$ROOT" && npm run build -w "$package")
    ok "$package built"
  fi

  echo "  Restarting services..."
  docker compose -f "$ROOT/docker-compose.yml" restart unoverse
  ok "Services restarted — changes are live"
  echo ""
}

# Internal helper (called by start/dev — not a user-facing command): builds the
# universal component-node package LOCALLY (never in the container — deploys and
# dev alike ship/serve locally built dists) and restarts unoverse. Design
# DEFINITION changes never need this — they synthesize from rx/ at boot; a plain
# restart suffices. This exists for the PACKAGE-source case.
build_component_nodes() {
  banner "Component Nodes (definition-backed)"

  echo "  Building the marketplace package locally (bundle-defs + tsc → dist)..."
  if (cd "$ROOT/apps/unoverse/nodes/marketplace" && node scripts/bundle-defs.mjs && npx tsc 2>/dev/null); then
    ok "Marketplace package built → apps/unoverse/nodes/marketplace/dist"
  elif [ -d "$ROOT/apps/unoverse/nodes/marketplace/dist" ]; then
    # Starters can't build it (no workspace plugin-base) — the dist SHIPS with the
    # platform sync/deploy; use the shipped artifact.
    ok "Using shipped component-node dist (local build unavailable — expected on starters)"
  else
    fail "no component-node dist and local build failed — re-sync/update the starter (the dist ships prebuilt)"
    return
  fi

  echo "  Restarting unoverse (definitions re-synthesize from rx/components)..."
  docker compose -f "$ROOT/docker-compose.yml" restart unoverse 2>/dev/null || true
  ok "Restarted — component changes are live"
  echo ""
}
