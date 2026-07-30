---
sidebarTitle: "Update Unoverse"
title: "Update Unoverse"
---

Keep your platform up to date when new versions are released.

## When to Update

Your Unoverse admin will notify you when a new platform version is available. Updates include bug fixes, new features, and performance improvements to the core services.

## Steps

### 1. Pull Latest Starter Code

```bash
cd ~/unoverse
git pull
```

This updates your `docker-compose.yml`, `unoverse` CLI, docs, and any shared config.

### 2. Update Platform Images

```bash
unoverse update
```

This pulls the latest Docker images, rebuilds packages, and restarts all services.

> **⚠️ Local changes to tracked files will be discarded.**
>
> `unoverse update` runs `git checkout -- .` before pulling to ensure a clean merge. This means any uncommitted edits to tracked files (e.g. `docker-compose.yml`, files in `nodes/` or `rx/`) will be lost.
>
> **Safe (never touched):** `.env`, `.env.production`, `node_modules/`, `package-lock.json` — these are gitignored.
>
> **If you have local changes you want to keep**, commit them to a branch first:
>
> ```bash
> git checkout -b my-changes
> git add -A && git commit -m "my local changes"
> git checkout main
> unoverse update
> git merge my-changes
> ```

### 3. Verify

```bash
unoverse check
```

All 14 checks should pass — services running, health endpoints, packages built, plugins loaded, and **Canvas** accessible.

---

## Updating Only Nodes

If you've changed packages but don't need new platform images:

```bash
unoverse update nodes
```

This rebuilds packages, generates nodes, and restarts only unoverse — much faster than a full `unoverse update`.

---

## ✅ Onboarding Complete!

For detailed node development, see the [Node Documentation](../nodes/overview.md).
