# unoverse docs

The developer documentation for the unoverse platform: onboarding, the design journey,
building nodes, architecture, and the runbooks.

This repository is the source of truth for [the docs site]. The site is Mintlify: connect
this repository once in the Mintlify dashboard and every push to `main` deploys.

## Working on it

```bash
npm run dev        # the site on http://localhost:3400
npm run check      # broken-link check
```

Content is plain Markdown (MDX in onboarding and welcome pages), navigation is `docs.json`,
theme overrides are `style.css`.

## Architecture diagrams

The figures under `images/architecture-*.svg` are generated, never hand-edited:

```bash
npm run diagrams
```

The generators live in `scripts/diagrams/`, one file per figure plus `arch.py`, the shared
drawing library. Change the facts in the generator, rerun, and commit both.

## Where changes come from

The monorepo is upstream. Content is authored there under `packages/docs` and synced here,
so fixes land in the monorepo first rather than diverging in two places.
