#!/usr/bin/env node
/**
 * unoverse new — scaffold a new project.
 *
 *   node new.mjs org <name> [rx-root]
 *
 * Projects live FLAT at the rx root (rx/<name>/), NOT under rx/orgs/. A project is
 * THEME-ONLY: it seeds just its brand themes (light/dark) from the marketplace
 * foundation; base + semantic tokens are INHERITED from the marketplace at resolve
 * time (theme.ts cascade), never copied. Override a foundation token later by adding
 * that file back under styles/ and editing it.
 *
 *   templates/      the project's apps
 *   components/     the project's own components (optional)
 *   styles/themes/  brand themes (light/dark) — everything else inherited
 *
 * Components and templates are authored (by hand, in Studio, or with the
 * unoverse-create skill) — there is no scaffold command for them.
 */
import { cpSync, existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join, resolve, relative } from "node:path";

const [kind, ...rest] = process.argv.slice(2);
const usage = () => {
  console.error("Usage:\n  unoverse new org <name>");
  process.exit(2);
};
if (kind !== "org") usage();

const name = rest[0] || usage();
const rootArg = rest[1];
const RX = [rootArg && resolve(rootArg), resolve("apps/unoverse/rx"), resolve("rx")]
  .filter(Boolean)
  .find((p) => existsSync(p));
if (!RX) { console.error("Cannot find an rx/ folder — run from the repo root."); process.exit(2); }

const slug = name.toLowerCase().replace(/[^a-z0-9-]/g, "");
if (!slug) usage();
const RESERVED = new Set(["default", "marketplace", "_schema", "orgs"]);
if (RESERVED.has(slug)) { console.error(`'${slug}' is reserved (the marketplace / schema), not a project.`); process.exit(1); }

const dir = join(RX, slug); // FLAT at the rx root — no orgs/ nesting
if (existsSync(dir)) { console.error(`rx/${slug} already exists`); process.exit(1); }

const foundationThemes = join(RX, "marketplace", "styles", "themes");
if (!existsSync(foundationThemes)) {
  console.error("rx/marketplace/styles/themes not found — cannot seed the project's brand themes.");
  process.exit(1);
}

const rel = (p) => relative(process.cwd(), p);

mkdirSync(join(dir, "templates"), { recursive: true });
mkdirSync(join(dir, "components"), { recursive: true });
// THEME-ONLY seed: just the brand themes. base + semantic are inherited from the
// marketplace foundation via the cascade — the project defines only what it changes.
cpSync(foundationThemes, join(dir, "styles", "themes"), { recursive: true });

writeFileSync(
  join(dir, "README.md"),
  `# ${slug}

A project on the platform — a theme over the shared marketplace:

| Folder | What lives here |
| --- | --- |
| \`components/\` | The project's own components — one folder per component (optional) |
| \`templates/\` | The project's apps — one folder per app (+ \`manifest.json\`) |
| \`styles/themes/\` | Brand themes (light/dark) — restyle freely |

Everything else — the base primitives, the semantic contract, the default theme, the
shared atoms and components — is INHERITED from the marketplace. To override a
foundation token, add that file under \`styles/base/\` or \`styles/semantic/\` and set the
value; keep the token NAME (the theme contract checks this).
`,
);

console.log(`Created project '${slug}' (rx/${slug}/):`);
console.log("  " + rel(join(dir, "templates")) + "/");
console.log("  " + rel(join(dir, "components")) + "/");
console.log("  " + rel(join(dir, "styles", "themes")) + "/   (brand themes — base+semantic inherited)");
console.log("");
console.log("Next: author components in Studio or with the unoverse-create skill,");
console.log("then run 'unoverse lint' to check your definitions.");
