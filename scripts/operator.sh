#!/usr/bin/env bash

# =============================================================================
# Unoverse Platform CLI
# =============================================================================
# Zero-dependency developer tool. Works immediately after git clone.
#
# NOT TYPED BY A HUMAN. The developer's command is the npm package `unoverse`, which
# finds a universe folder and calls this. There is no `./unoverse` any more: one binary,
# everywhere (2026-07-31). This file is the operator half of it.
#
# The surface is deliberately small. Commands that were separate ways to ask the same
# question got folded, not renamed:
#   doctor, db-verify, status  →  check
#   db-setup                   →  runs inside create and deploy
#   open                       →  where (in the npm CLI; it already prints the addresses)
# Kept, but not advertised: ground, dev, build, publish, update nodes.
# =============================================================================

# Resolve lib/ directory relative to this script
GRAVITY_LIB="$(cd "$(dirname "$0")" && pwd)"
# If script is at project root (not in scripts/), lib is at scripts/lib
# If script is in scripts/, lib is at scripts/lib
if [ -d "$GRAVITY_LIB/lib" ]; then
  GRAVITY_LIB="$GRAVITY_LIB/lib"
elif [ -d "$GRAVITY_LIB/scripts/lib" ]; then
  GRAVITY_LIB="$GRAVITY_LIB/scripts/lib"
else
  echo "Error: Cannot find scripts/lib/ directory" >&2
  exit 1
fi

# ── Source all modules ──────────────────────────────────────────────
source "$GRAVITY_LIB/find-root.sh"
source "$GRAVITY_LIB/common.sh"
source "$GRAVITY_LIB/init.sh"
source "$GRAVITY_LIB/start.sh"
source "$GRAVITY_LIB/stop.sh"
source "$GRAVITY_LIB/logs.sh"
source "$GRAVITY_LIB/update.sh"
source "$GRAVITY_LIB/doctor.sh"
source "$GRAVITY_LIB/dev.sh"
source "$GRAVITY_LIB/check.sh"
source "$GRAVITY_LIB/dashboard.sh"
source "$GRAVITY_LIB/help.sh"
source "$GRAVITY_LIB/db-setup.sh"
source "$GRAVITY_LIB/db-verify.sh"
source "$GRAVITY_LIB/deploy.sh"
source "$GRAVITY_LIB/ground.sh"
# Authoring tools (lint, new, node test/hash, studio) moved to _legacy/scripts-lib
# 2026-07-28 — authoring lives in Studio now. The CLI is the OPERATOR tool.
# Owner-only module — absent in the starter kit by design.
[ -f "$GRAVITY_LIB/publish.sh" ] && source "$GRAVITY_LIB/publish.sh"

# ── Dispatch ───────────────────────────────────────────────────────
# (The old "studio mode" gate is gone — 2026-07-28. This CLI has ONE job:
# operate a universe. Studio is a separate app; authoring happens there.)
case "${1:-}" in
  init)      cmd_init ;;
  start)     cmd_start ;;
  stop)      cmd_stop ;;
  status)    cmd_check ;;   # alias — status merged into check 2026-07-28
  logs)      cmd_logs "${2:-}" ;;
  update)
    if [ "${2:-}" = "nodes" ]; then
      cmd_update_nodes
    else
      cmd_update
    fi
    ;;
  # ONE question, one command. `check` runs the health check, then the schema check,
  # then the deeper environment diagnosis — the three things that used to be `check`,
  # `db-verify` and `doctor`, which nobody could pick between.
  check)     cmd_check && cmd_db_verify && cmd_doctor ;;
  doctor|db-verify|db-setup)
    echo "  '$1' folded into 'unoverse check' (db-setup runs inside create and deploy)"
    exit 1 ;;
  dev)       cmd_dev ;;
  _db-setup) cmd_db_setup ;;   # internal: called by create and deploy
  ground)    shift; cmd_ground "$@" ;;
  deploy)
    # `deploy marketplace` is PLATFORM-OWNER only: it publishes the marketplace package
    # to npm, which a starter developer never does (they INSTALL from the marketplace).
    # It lives in publish.sh, the owner-only module sync-starter.sh strips, so on a
    # starter kit this branch simply reports that it is not their command.
    if [ "${2:-}" = "marketplace" ]; then
      if type cmd_deploy_marketplace >/dev/null 2>&1; then shift 2; cmd_deploy_marketplace "$@"
      else echo "deploy marketplace is a platform-owner command. Not available in the starter kit"; exit 1; fi
    else
      shift; cmd_deploy "$@"
    fi
    ;;
  publish)
    # TWO MEANINGS, decided by which kit you are in.
    #   monorepo  `publish` is the PLATFORM RELEASE (publish.sh, owner-only), so a
    #             developer publish is `publish assets <project>`.
    #   starter   sync-starter.sh strips publish.sh, so the name is free and `publish`
    #             means the only publish a developer has.
    if [ "${2:-}" = "assets" ]; then
      shift 2; node --import tsx "$GRAVITY_LIB/publish-assets.mjs" "$@"
    elif type cmd_publish >/dev/null 2>&1; then
      shift; cmd_publish "$@"
    else
      shift; node --import tsx "$GRAVITY_LIB/publish-assets.mjs" "$@"
    fi
    ;;
  build)     cmd_build "${2:-}" ;;
  open)      echo "  'open' folded into 'unoverse where'"; exit 1 ;;
  help|--help|-h) cmd_help ;;
  "")        cmd_dashboard ;;
  *)
    echo "Unknown command: $1"
    echo "Run unoverse help for usage"
    exit 1
    ;;
esac

