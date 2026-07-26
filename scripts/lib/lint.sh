#!/usr/bin/env bash
# unoverse lint — authoring-time linters (schema + guard rules)
#
#   lint          rx/ definitions
#   lint nodes    declarative node manifests
#   lint all      both

cmd_lint() {
  if ! command -v node >/dev/null 2>&1; then
    echo "unoverse lint requires Node.js 20+"; exit 1
  fi

  case "${1:-}" in
    nodes)
      node "$GRAVITY_LIB/lint-nodes.mjs" "${2:-$ROOT/apps/unoverse/nodes}"
      ;;
    all)
      local rx=0 nodes=0
      node "$GRAVITY_LIB/lint.mjs" "$ROOT/apps/unoverse/rx" || rx=$?
      echo ""
      node "$GRAVITY_LIB/lint-nodes.mjs" "$ROOT/apps/unoverse/nodes" || nodes=$?
      [ "$rx" -ne 0 ] || [ "$nodes" -ne 0 ] && return 1
      return 0
      ;;
    *)
      node "$GRAVITY_LIB/lint.mjs" "${1:-$ROOT/apps/unoverse/rx}"
      ;;
  esac
}

# unoverse node <sub> — declarative node manifests
cmd_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "unoverse node requires Node.js 20+"; exit 1
  fi
  case "${1:-}" in
    lint) node "$GRAVITY_LIB/lint-nodes.mjs" "${2:-$ROOT/apps/unoverse/nodes}" ;;
    test)
      [ -n "${2:-}" ] || { echo "Usage: unoverse node test <NodeType>"; exit 1; }
      # tsx: the manifest runtime is TypeScript source, not a build output.
      (cd "$ROOT" && node --import tsx "$GRAVITY_LIB/test-node.mjs" "$2" "${3:-$ROOT/apps/unoverse/nodes}")
      ;;
    *) echo "Usage: unoverse node <lint|test> [args]"; exit 1 ;;
  esac
}
