---
sidebarTitle: "Restart & Rebuild"
title: "Runbook: Restart & Rebuild"
---

Rebuild packages and restart services so the platform picks up your latest changes. Component nodes are definition-backed — they re-synthesize from `rx/` at boot; there is no generation step, ever.

## When To Use

- New or updated **rx definitions** (components, atoms, templates, styles in `apps/unoverse/rx/`)
- New or updated **custom node packages** (in `apps/unoverse/nodes/`)
- New or updated **prompts** (agent skills / prompt blocks in `apps/unoverse/prompts/`)
- After `git pull` or `unoverse update` when the platform isn't reflecting changes

## Quick Commands

### Local Development

```bash
# Full rebuild — builds all node packages, restarts services
./unoverse build

# Build one package only
./unoverse build @unoverse-platform/my-package

# Restart only — component nodes re-synthesize from rx/ definitions at boot
./unoverse build

# Full dev setup — install deps, build, restart
./unoverse dev
```

### Production Server

Content does not ride deploys. Nodes, design, and prompts reach a server through
`unoverse update` (git-synced carve-out), the Marketplace (installed per item,
database-driven), and Studio publish. `unoverse deploy` moves platform images only:

```bash
unoverse deploy    # pull latest images + restart
```

## What Each Step Does

| Step | Command | What happens |
|------|---------|-------------|
| **1. Install deps** | `npm install` | Installs workspace dependencies |
| **2. Build packages** | `npm run build` | Compiles node packages (TypeScript → `dist/`) |
| **3. Restart unoverse** | `./unoverse build` | Reloads built packages, and re-synthesizes component nodes from `rx/` definitions — the node catalog is loaded **at boot**, so a rebuild without a restart appears to do nothing |

## Which change needs which step?

| You changed | Do |
|---|---|
| A node package (`apps/unoverse/nodes/<pkg>/`) | `./unoverse build @unoverse-platform/<pkg>` |
| An **existing** component/template's look (`rx/`) | nothing — definitions are read live; hard-refresh the client |
| A **new** component, or props/structure changes (`rx/`) | `./unoverse build` |
| A skill or prompt block (`prompts/`) | `./unoverse build` |

## Manual Step-by-Step (when CLI commands aren't enough)

```bash
# 1. Install dependencies
npm install

# 2. Build all node packages
npm run build

# 3. Restart the service that loads packages (the workflow engine runs
#    in-process in unoverse, so one restart covers everything — component
#    nodes re-synthesize from rx/ at this boot)
./unoverse build

# 4. Verify
./unoverse status
```

## Nuclear Restart (full teardown + rebuild)

When things are truly stuck:

```bash
./unoverse stop
npm install
npm run build
./unoverse start
```

`unoverse start` also rebuilds the universal component-node package in-container, so a cold start always runs fresh executor code.

## Verify

```bash
# Check all services are running
./unoverse status

# Full health check
./unoverse check

# Check nodes loaded in unoverse (:4106 is Docker-internal and :4105 /plugins
# is JWT-gated, so count from inside the container)
docker compose exec -T unoverse node -e \
  "fetch('http://127.0.0.1:4106/nodes').then(r=>r.json()).then(d=>console.log((d.nodes||[]).length)).catch(()=>console.log(0))"
```

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| New component not in **Canvas** | unoverse not restarted since the definition was added | `./unoverse build` |
| Node shows in **Canvas** but errors | Package not built | `./unoverse build` |
| Component renders old version | Client caching | hard-refresh the browser |
| `nodes: 0` in status | unoverse didn't load packages | Check `docker compose logs unoverse` |
| Build fails | Dependencies missing | `npm install`, then `./unoverse build` |

## Related

- [01-core.md](./01-core.md) — Initial deployment
- [06-test.md](./06-test.md) — Full health check
