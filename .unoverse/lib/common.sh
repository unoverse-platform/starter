#!/usr/bin/env bash
# Shared colors, helpers, and constants

GRAVITY_VERSION="1.0.0"
DOCR_REGISTRY="registry.digitalocean.com"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
UNDERLINE='\033[4m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${DIM}$1${NC}"; }
link() { echo -e "  ${CYAN}${UNDERLINE}$1${NC}"; }
banner() {
  echo ""
  echo -e "  ${BOLD}${CYAN}⬡ $1${NC}"
  echo -e "  ${DIM}─────────────────────────────────${NC}"
}

# The branded access box. ONE definition so start.sh, update.sh and dashboard.sh
# never drift apart again.
print_access_urls() {
  echo -e "  ${WHITE}${BOLD}unoverse${NC}${DIM}, the experience layer for AI${NC}"
  echo -e "  ${DIM}Use the Unoverse MCP to build agents. Somewhere, Skynet is taking notes. 🤖${NC}"
  echo ""
  echo -e "  ${CYAN}Canvas${NC}  ${DIM}(build agents)${NC}   ${UNDERLINE}http://localhost:3001${NC}"
  echo -e "  ${CYAN}Studio${NC}  ${DIM}(build assets)${NC}   ${UNDERLINE}http://localhost:3002${NC}"
  echo -e "  ${CYAN}API${NC}     ${DIM}(REST + MCP)${NC}     ${UNDERLINE}http://localhost:4105${NC}"
  echo ""
  echo -e "  ${DIM}▶ Next:${NC} open this repo in ${BOLD}Claude Code${NC} and ask it to build an agent"
}

# Elapsed time helper
timer_start() { GRAVITY_START=$(date +%s); }
timer_elapsed() {
  local end=$(date +%s)
  local elapsed=$((end - GRAVITY_START))
  if [ $elapsed -ge 60 ]; then
    echo "$((elapsed / 60))m $((elapsed % 60))s"
  else
    echo "${elapsed}s"
  fi
}

# The old "studio mode" system (mode file, is_platform_mode, require_platform_mode)
# was removed 2026-07-28: Studio is a separate app now, and this CLI has one job:
# operate a universe. See _legacy/scripts-lib/ for the retired authoring tools.
