#!/usr/bin/env bash
# unoverse key — issue, list and revoke the publish keys for THIS universe.
#
# A publish key is a DELEGATED form of an Auth0 account's publish permission, for the two
# cases a browser login cannot reach: CI/headless, and the first credential on a new
# universe. The normal path is a developer logging in, since unoverse requires auth.
# The key is the exception, not the rule (docs/architecture/DECLARATIVE_NODES.md §9.4).
#
# WHY THIS IS A LOCAL COMMAND AND NOT AN API. Issuing keys is the root of the trust
# chain, so it is reachable only from the universe itself. The routes live on the
# engine's :4101 loopback listener, which is not published, and `publish-keys` is
# deliberately absent from the /api/* allowlist. You must be on the box, or able to
# exec into the container, which is the same bar as reading the database directly.
#
# Two environments, the same split db-setup uses:
#   local dev   curl the engine on 127.0.0.1:4101
#   starter     docker compose exec into the unoverse container and curl from inside

ENGINE_LOCAL="http://127.0.0.1:4101"

# Run one request against the engine, wherever the engine happens to be.
#   _key_request METHOD PATH [JSON_BODY]
_key_request() {
  local method="$1" path="$2" body="${3:-}"
  local args=(-sS -X "$method" "${ENGINE_LOCAL}${path}")
  if [ -n "$body" ]; then
    args+=(-H "content-type: application/json" -d "$body")
  fi

  if [ -d "$ROOT/apps/unoverse/engine" ]; then
    # Local dev: the engine runs in the unoverse process on this machine.
    curl "${args[@]}"
  else
    # Starter: curl from INSIDE the container, so :4101 stays unpublished.
    docker compose -f "$ROOT/docker-compose.yml" exec -T unoverse curl "${args[@]}"
  fi
}

# The engine must be up: these routes are served by the running process, not the DB.
_key_require_engine() {
  if ! _key_request GET /health >/dev/null 2>&1; then
    fail "cannot reach the engine on :4101. Start the platform first: ./unoverse start"
    return 1
  fi
}

_key_create() {
  local owner="$1" label="$2" days="${3:-90}"
  if [ -z "$owner" ] || [ -z "$label" ]; then
    fail "usage: ./unoverse key create <owner> \"<label>\" [days]"
    echo -e "  ${DIM}owner is the Auth0 account the key acts as, e.g. an email. What the key"
    echo -e "  publishes is owned by that account, so rotating the key changes nothing."
    echo -e "  label is how you know which key to revoke later, e.g. \"CI\".${NC}"
    return 1
  fi
  _key_require_engine || return 1

  local response
  response=$(_key_request POST /publish-keys "{\"label\":$(_key_json_string "$label"),\"expiresInDays\":$days,\"ownerId\":$(_key_json_string "$owner"),\"ownerLabel\":$(_key_json_string "$owner"),\"createdBy\":$(_key_json_string "$(whoami)@$(hostname -s)")}")

  local key
  key=$(echo "$response" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);if(j.key)console.log(j.key);else{console.error(j.error||s);process.exit(1)}}catch(e){console.error(s);process.exit(1)}})") || {
    fail "could not issue the key"
    return 1
  }

  echo ""
  ok "Publish key issued to ${GREEN}${owner}${NC} (${label}), valid ${days} days"
  echo ""
  echo -e "  ${YELLOW}${key}${NC}"
  echo ""
  echo -e "  ${DIM}This is the only time it is shown. It is stored hashed, so nobody,"
  echo -e "  including you, can read it back. Lost means issue another.${NC}"
  echo ""
  echo -e "  Give it to the developer to run:"
  echo -e "    ${GREEN}unoverse connect <your-universe-url>${NC}"
  echo ""
}

_key_list() {
  _key_require_engine || return 1
  local response
  response=$(_key_request GET /publish-keys)
  echo "$response" | node -e "
    let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{
      let j; try { j = JSON.parse(s); } catch { console.error(s); process.exit(1); }
      // An error must never render as 'no keys'. 'You have none' and 'I could not
      // find out' look identical on screen and mean opposite things.
      if (j.error || !Array.isArray(j.publishKeys)) { console.error('  ' + (j.error || s)); process.exit(1); }
      const rows = j.publishKeys;
      if (!rows.length) { console.log('\n  No publish keys issued.\n'); return; }
      const now = Date.now();
      console.log('');
      for (const r of rows) {
        const dead = r.revoked_at ? 'revoked' : (new Date(r.expires_at) <= now ? 'expired' : 'active');
        const used = r.last_used_at ? new Date(r.last_used_at).toISOString().slice(0,10) : 'never used';
        console.log('  ' + dead.padEnd(8) + r.key_prefix.padEnd(14) + String(r.owner_label || r.owner_id || 'no owner').padEnd(24) + String(r.label).padEnd(16) + 'expires ' + new Date(r.expires_at).toISOString().slice(0,10) + '  ' + used);
        console.log('           ' + r.id);
      }
      console.log('');
    });
  "
}

_key_revoke() {
  local id="$1"
  if [ -z "$id" ]; then
    fail "an id is required: ./unoverse key revoke <id>   (./unoverse key list shows them)"
    return 1
  fi
  _key_require_engine || return 1
  local response
  response=$(_key_request POST "/publish-keys/$id/revoke")
  echo "$response" | node -e "
    let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{
      let j; try { j = JSON.parse(s); } catch { console.error(s); process.exit(1); }
      if (j.error) { console.error('  ' + j.error); process.exit(1); }
      const k = j.publishKey;
      console.log('');
      console.log(j.alreadyRevoked ? '  Already revoked: ' + k.label : '  Revoked: ' + k.label + ' (' + k.key_prefix + ')');
      console.log('  Anything it published keeps its attribution.');
      console.log('');
    });
  "
}

# JSON-escape a shell string without assuming jq is installed.
_key_json_string() {
  node -e "console.log(JSON.stringify(process.argv[1]))" "$1"
}

cmd_key() {
  case "${1:-}" in
    create) shift; _key_create "${1:-}" "${2:-}" "${3:-90}" ;;
    list|ls|"") _key_list ;;
    revoke) shift; _key_revoke "${1:-}" ;;
    *)
      echo "Unknown key command: $1"
      echo ""
      echo "  ./unoverse key create <owner> \"<label>\" [days]   Issue a key (shown once)"
      echo "  ./unoverse key list                       Show issued keys"
      echo "  ./unoverse key revoke <id>                Kill one now"
      exit 1
      ;;
  esac
}
