#!/usr/bin/env bash
# unoverse deploy — deploy to production VM from local

cmd_deploy() {

  local env_prod="$ROOT/.env.production"

  if [ ! -f "$env_prod" ]; then
    fail ".env.production not found"
    echo ""
    info "Terraform renders it, complete (see .env.production.example):"
    info "  cd infra/digitalocean && terraform apply"
    info "  terraform output -raw env_production > ../../.env.production"
    echo ""
    exit 1
  fi

  # Read deploy target from .env.production
  local deploy_host deploy_user
  deploy_host=$(grep '^DEPLOY_HOST=' "$env_prod" | cut -d= -f2- | tr -d '\r\n' | xargs)
  deploy_user=$(grep '^DEPLOY_USER=' "$env_prod" | cut -d= -f2- | tr -d '\r\n' | xargs)

  if [ -z "$deploy_host" ] || [ "$deploy_host" = "your-vm-ip" ]; then
    fail "DEPLOY_HOST is not set in .env.production"
    exit 1
  fi
  deploy_user="${deploy_user:-root}"

  banner "Deploying to $deploy_host"
  echo ""
  timer_start

  # Check ansible is installed
  if ! command -v ansible-playbook &>/dev/null; then
    fail "Ansible is not installed"
    info "Install: pip install ansible"
    exit 1
  fi
  ok "Ansible available"

  # Generate a temporary inventory from .env.production
  local tmp_inventory
  tmp_inventory=$(mktemp).yml
  cat > "$tmp_inventory" << 'EOF'
all:
  hosts:
    gravity-prod:
      ansible_host: DEPLOY_HOST_PLACEHOLDER
      ansible_user: DEPLOY_USER_PLACEHOLDER
      ansible_python_interpreter: /usr/bin/python3
EOF

  # Replace placeholders with actual values
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/DEPLOY_HOST_PLACEHOLDER/$deploy_host/g" "$tmp_inventory"
    sed -i '' "s/DEPLOY_USER_PLACEHOLDER/$deploy_user/g" "$tmp_inventory"
  else
    sed -i "s/DEPLOY_HOST_PLACEHOLDER/$deploy_host/g" "$tmp_inventory"
    sed -i "s/DEPLOY_USER_PLACEHOLDER/$deploy_user/g" "$tmp_inventory"
  fi

  # Debug: show what's in the inventory
  echo ""
  info "Generated inventory file:"
  cat "$tmp_inventory" | sed 's/^/  /'
  echo ""

  local ansible_dir="$ROOT/ansible"
  # ansible only reads ansible.cfg from CWD/env — we run from the repo root, so
  # point it at ours explicitly (inventory defaults, deprecation-noise silencing).
  export ANSIBLE_CONFIG="$ansible_dir/ansible.cfg"
  local subcommand="${1:-}"

  case "$subcommand" in
    ""|deploy)
      # THE deploy: the server takes the latest platform images (pull + restart).
      # Content does NOT ride deploys — it arrives via git (`unoverse update`
      # pulls the starter clone incl. the carve-out), the marketplace (DB-driven,
      # self-healing at boot) and, when the gate lands, Studio publish.
      info "Deploying platform images..."
      echo ""
      ansible-playbook \
        -i "$tmp_inventory" \
        "$ansible_dir/playbooks/deploy-images.yml" \
        -e "env_file=$env_prod"
      ;;
    init|full)
      # FIRST-TIME provisioning only (base host + services).
      info "First-time provisioning (install)..."
      echo ""
      ansible-playbook \
        -i "$tmp_inventory" \
        "$ansible_dir/playbooks/install.yml" \
        -e "env_file=$env_prod"
      ;;
    db)
      info "Running database setup..."
      echo ""
      ansible-playbook \
        -i "$tmp_inventory" \
        "$ansible_dir/playbooks/db-setup.yml" \
        -e "env_file=$env_prod"
      ;;
    test|check)
      info "Running connectivity test..."
      echo ""
      ansible-playbook \
        -i "$tmp_inventory" \
        "$ansible_dir/playbooks/test-connectivity.yml" \
        -e "env_file=$env_prod"
      ;;
    harden)
      info "Hardening VM (SSH, firewall, updates)..."
      echo ""
      ansible-playbook \
        -i "$tmp_inventory" \
        "$ansible_dir/playbooks/harden.yml"
      ;;
    *)
      echo "Usage: unoverse deploy [command]"
      echo ""
      echo "  (none)       Deploy your platform: pull images + ship your work"
      echo "               (your nodes built locally, rx, prompts) + restart."
      echo ""
      echo "Runtime:"
      echo ""
      echo "Fast lane:"
      echo ""
      echo "Setup & utilities:"
      echo "  init         First-time provisioning (install + carve-out)"
      echo "  db           Run database setup"
      echo "  harden       Security hardening (SSH, firewall, updates)"
      echo "  test         Run connectivity test"
      rm -f "$tmp_inventory"
      exit 1
      ;;
  esac

  rm -f "$tmp_inventory"

  echo ""
  echo -e "  ${GREEN}${BOLD}Done${NC} ${DIM}in $(timer_elapsed)${NC}"
  echo ""
}
