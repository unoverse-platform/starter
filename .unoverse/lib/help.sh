#!/usr/bin/env bash
# unoverse help, the OPERATOR half.
#
# Printed by the npm CLI when you are standing in a universe folder. It lists what you
# can do to a universe, and nothing else. Commands that still exist but are not for
# day-to-day operating (ground, dev, build, publish) are deliberately absent: a list you
# can read in one glance is worth more than a complete one.

cmd_help() {

  echo ""
  echo -e "  ${BOLD}${CYAN}⬡ unoverse${NC} ${DIM}v${GRAVITY_VERSION}${NC}"
  echo ""
  echo -e "  ${BOLD}Anywhere${NC}"
  echo -e "    ${GREEN}create${NC}      Start something new, here"
  echo -e "    ${GREEN}studio${NC}      Author components, nodes, agent skills"
  echo -e "    ${GREEN}where${NC}       Your universe's addresses"
  echo -e "    ${GREEN}update${NC}      Update this CLI"
  echo ""
  echo -e "  ${BOLD}This universe${NC}"
  echo -e "    ${GREEN}start${NC}       Start it"
  echo -e "    ${GREEN}stop${NC}        Stop it"
  echo -e "    ${GREEN}check${NC}       Is it healthy ${DIM}(services, schema, environment)${NC}"
  echo -e "    ${GREEN}logs${NC}        What is it doing ${DIM}(unoverse logs <service> for one)${NC}"
  echo -e "    ${GREEN}deploy${NC}      Ship it to your server ${DIM}(images + your work + migrations)${NC}"
  echo ""
  # Owner-only lane. Printed ONLY when publish.sh is present, so a starter kit never
  # advertises a command it does not have (sync-starter.sh deletes that file).
  if type cmd_publish >/dev/null 2>&1; then
    echo -e "  ${BOLD}${DIM}Platform owner${NC}"
    echo -e "    ${GREEN}publish${NC}     Full release. Every lane whose content changed"
    echo -e "    ${GREEN}ground${NC}      Prefill terraform.tfvars from your cloud CLI ${DIM}(do|aws)${NC}"
    echo -e "    ${GREEN}dev${NC}         Run the monorepo locally"
    echo ""
  fi
}
