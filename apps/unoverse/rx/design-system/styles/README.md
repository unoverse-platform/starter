# Unoverse Design Tokens (`rx/styles/`)

The design language — the single, neutral source of truth for the Unoverse look.
Components in `rx/components/` reference **semantic** tokens only; the SDKs map the
resolved values to native (CSS on web, SwiftUI on iOS, Compose on Android).

## ⚠️ This folder is TOKENS ONLY

`rx/styles/` holds **tokens** — colors, spacing, type, radius, shadow. The *language*.
It does **not** hold component styling. A component's look (e.g. "a primary button") is a
**component concern** — it belongs in that component's definition (`rx/atoms/` / `rx/components/`),
which references these tokens. And the **SDK holds no styles at all** — it just resolves tokens
(see the SDK README "GOLDEN RULE").

> Example done right: the button's full style lives in the **Button atom** (`rx/atoms/button.json`),
> referencing tokens; components **compose** that atom (a `Ref` node, expanded server-side). There is
> NO button "recipe" here and NO `buttonStyle` in the SDK. Do not add component recipes to this folder.

## Two tiers

| Tier | Folder | What | Named by |
|------|--------|------|----------|
| **Base** | `base/` | raw palettes + scales — the ingredients | what it **is** (`color.primary.500`, `space.4`) |
| **Semantic** | `themes/`, `semantic/` | meaning, points at base — what components use | what it's **for** (`color.text.primary`, `text.headline`) |

A component says `"color": "text.primary"`. It never knows the hex. Swap the
**theme** (the semantic color layer) → dark mode or a new brand, with **zero
component changes**. That is the whole flexibility win.

## This is the DEFAULT org — the starter, not a client

Client brands do **not** live here, and no client renders from this folder. Each
client org owns a **complete copy** of a styles set at `rx/orgs/<org>/styles/` —
100% split, self-contained, no overlay or fallback (see `rx/orgs/README.md`).
This folder is two things:

1. the **default** tokens the universal components preview under
   (`unoverse://theme/default/light`; bare `theme/light` resolves here too — legacy);
2. the **starter** that `npm run new-org <name>` copies for a new client.

The token *names* defined here are the shared contract components rely on — every
org's set must define them all (guarded by `theme-contract.test.ts`); the *values*
are each client's own. The `light`/`dark` themes here stay brand-free.

```
base/        raw scales (one file per category)
├── color.json        palettes: primary(green), secondary(teal), gray, status, chart
├── typography.json   font families, size scale, weights, line-heights
├── spacing.json      the spacing scale
├── radius.json       border radii
├── shadow.json       elevation
├── border.json       border widths
└── motion.json       transitions + easing
semantic/
└── text-styles.json  composed text styles (headline/title/body/caption) — theme-independent
themes/
├── light.json        semantic color layer (text/surface/border/action/status) → base
└── dark.json         dark variant (starter — refine against a canonical dark source)
```

## Format

[W3C Design Tokens](https://www.designtokens.org/) (`$value` / `$type`, aliases as
`{group.token}`). Plain JSON, but standard — so a compiler (Style Dictionary) can later
emit the per-platform token files (CSS today; SwiftUI/Compose for the native SDKs) from
this one source.

## Provenance

Seeded from the canonical Gravity tokens (`apps/design-system/storybook/styles/{colors,tokens}.css`)
— NOT invented. Note the primary brand is **green `#10b981`**. Typography scale is a
sensible starting scale (the source CSS sets type per-component, not as tokens) — refine
as components demand. `dark.json` is a starter pending a canonical dark palette.
