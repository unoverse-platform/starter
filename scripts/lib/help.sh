#!/usr/bin/env bash
# unoverse help

cmd_help() {

  echo ""
  echo -e "  ${BOLD}${CYAN}⬡ Unoverse Platform CLI${NC} ${DIM}v${GRAVITY_VERSION}${NC}"
  echo ""
  echo -e "  ${BOLD}Setup${NC}"
  echo -e "    ${GREEN}init${NC}        Interactive setup wizard"
  echo -e "    ${GREEN}doctor${NC}      Diagnose environment issues"
  echo ""
  echo -e "  ${BOLD}Platform${NC}"
  echo -e "    ${GREEN}start${NC}       Start all services"
  echo -e "    ${GREEN}stop${NC}        Stop all services"
  echo -e "    ${GREEN}check${NC}       Run full health check"
  echo -e "    ${GREEN}logs${NC}        Open the Dozzle log viewer ${DIM}(./unoverse logs <service> streams one in the terminal)${NC}"
  echo -e "    ${GREEN}update${NC}      Pull latest images and restart"
  echo -e "    ${GREEN}open${NC}        Open in browser ${DIM}(./unoverse open canvas|api|logs)${NC}"
  echo ""
  echo -e "  ${BOLD}Development${NC}"
  echo -e "    ${GREEN}dev${NC}         Install deps, gen nodes, start platform"
  echo -e "    ${GREEN}db-setup${NC}    Run database migrations ${DIM}(safe to re-run)${NC}"
  echo -e "    ${GREEN}db-verify${NC}   Verify database schema against Prisma"
  echo -e "    ${GREEN}build${NC}       Build and restart ${DIM}(./unoverse build <package>)${NC}"
  echo ""
  echo -e "  ${BOLD}Deployment${NC}"
  echo -e "    ${GREEN}ground${NC}                  Prefill terraform.tfvars from your cloud CLI ${DIM}(./unoverse ground do|aws)${NC}"
  echo -e "    ${GREEN}deploy${NC}                  Deploy your platform: images + your work → your server"
  echo -e "    ${GREEN}deploy init${NC}             First-time setup: install + db + verify (harden is your call, after)"
  echo -e "    ${GREEN}deploy db${NC}               Re-run database setup on server"
  echo -e "    ${GREEN}deploy harden${NC}           Re-run security hardening"
  # Owner-only lane. Printed ONLY when publish.sh is present, so a starter kit never
  # advertises a command it does not have (sync-starter.sh deletes that file).
  if type cmd_deploy_marketplace >/dev/null 2>&1; then
    echo -e "    ${GREEN}deploy marketplace${NC}      Publish the marketplace: design system, skills, blocks, nodes"
    echo -e "    ${GREEN}publish base${NC}            Publish the node runtime open source: npm + github"
    echo -e "    ${GREEN}publish tools${NC}           Publish the CLI + Studio to npm, drifted ones only"
  fi
  echo -e "    ${GREEN}deploy test${NC}             Run connectivity test"
  echo ""
}
