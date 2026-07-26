#!/usr/bin/env node
/**
 * unoverse lint — the rx/ definition linter.
 *
 * Enforces the LOCKED anatomy (the CardFinder/JourneyFinder + bppchatlayout
 * exemplars) as a standalone authoring-time check (no deps). Errors fail
 * (exit 1); warnings and hints inform. Every message cites the owning doc.
 *
 * The anatomy it enforces:
 *
 *   COMPONENT  rx/components/<name>/
 *     <name>.json            envelope: unoverse/kind/name/category, nodeSize?,
 *                            outputs?, state:{}?, stateOrder:[]?, root (a Switch
 *                            on `defaultState` → layouts/compact | layouts/full)
 *     manifest.json          OPTIONAL — spatial discovery (title/description/
 *                            whenToUse/category/version). NO binding.
 *     layouts/*.json         the faces (compact = inline · full = focused)
 *     components/*.json      sub-partials ($include'd shapes)
 *     states/*.json          wizard-step layers (the Studio state picker)
 *
 *   TEMPLATE   rx/orgs/<org>/templates/<name>/
 *     manifest.json          THE ENVELOPE: name/description/whenToUse/category/
 *                            version/defaultState/inputSchema/stateOrder:[]/
 *                            binding{workflow,trigger}/layout (width/focusWidth deprecated)
 *     layouts/<layout>.json  the root tree (named by manifest.layout) · root appWidth =
 *                            the app's constant core width; panel appWidth = slide-out
 *     components/*.json       sub-partials
 *     states/*.json           layers
 *
 * Content has THREE homes (§3 microapp discipline): hardcoded literals in the
 * def · the `state:{}` block (keys the def's own actions write) · `props` with
 * `input:true` (workflow-fed). A contained microapp has empty/absent props.
 *
 * Usage: node lint.mjs [path-to-rx]   (default: ./apps/unoverse/rx or ./rx)
 */
import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join, relative, dirname, basename, resolve, sep } from "node:path";
import { createRequire } from "node:module";

// ── definition file formats (mirrors server/src/fsCache.ts) ──
// A LOCAL copy, not an import: this script ships standalone to the starter and cannot
// reach the server's TypeScript. `.yaml` first, matching the loader's resolution order.
// If these ever disagree with fsCache.ts, lint checks a different set of files than the
// server serves — which is exactly the silent gap this block exists to close.
const DEF_EXTS = [".yaml", ".json"];
const isDefFile = (f) => DEF_EXTS.some((e) => f.endsWith(e));
const defName = (f) => f.replace(/\.(yaml|json)$/, "");
const defPath = (dir, name) => {
  for (const e of DEF_EXTS) {
    const p = join(dir, name + e);
    if (existsSync(p)) return p;
  }
  return undefined;
};

// YAML is required LAZILY, only when a .yaml definition is actually read, so a JSON-only
// project (and a fresh starter clone that has not installed devDependencies) never needs
// the package — the "no deps" property above holds for everyone not authoring YAML.
let _yamlParse = null;
function parseDef(text, file) {
  if (!file.endsWith(".yaml")) return JSON.parse(text);
  if (!_yamlParse) {
    try {
      _yamlParse = createRequire(import.meta.url)("yaml").parse;
    } catch {
      throw new Error('YAML definitions need the "yaml" package — run: npm i -D yaml');
    }
  }
  return _yamlParse(text);
}
const readDef = (file) => parseDef(readFileSync(file, "utf8"), file);

// ── ground truth (mirrors rx/_schema/unoverse.schema.json + server guards) ──
const PRIMITIVES = new Set([
  "Box", "Stack", "Row", "Column", "Each", "Switch", "ComponentSlot", "Timeline",
  "Text", "Image", "Button", "Input", "Markdown", "Skeleton", "Icon", "Ref",
]);
const CONDITION_KEYS = new Set(["field", "eq", "ne", "in"]);
// the portable style vocabulary — every key the SDK interpreter maps (sdk/style.ts).
// Each is a neutral intent every native renderer (iOS/Android/RN/Flutter) implements;
// an unknown key is a typo or a web-ism that renders nowhere.
const STYLE_KEYS = new Set([
  "width", "height", "maxWidth", "minWidth", "minHeight", "maxHeight", "flex",
  "padding", "margin", "gap", "overflow",
  "position", "inset", "top", "right", "bottom", "left", "zIndex",
  "direction", "wrap", "align", "justify", "display", "columns", "container", "hideBelow",
  "background", "radial", "border", "borderTop", "borderRight", "borderBottom", "borderLeft",
  "outline", "shadow", "radius", "radiusTopLeft", "radiusTopRight", "radiusBottomLeft", "radiusBottomRight",
  "font", "weight", "lineHeight", "color", "textAlign", "fit",
  "transform", "transition", "animation", "animationDelay", "cursor",
  "hover", "active", "when",
]);
// exact regex from server/src/runtime/definition-tokens.test.ts
const RAW_VALUE = /#[0-9a-fA-F]{3,8}\b|\b\d*\.?\d+(px|rem|em)\b/;
// nodes reachable through these keys (data keys like `items`/`cases` handled explicitly)
const CHILD_NODE_KEYS = ["children", "template", "fallback", "user", "assistant"];
// folders that hold BARE PARTIALS one level under the definition root
const PARTIAL_DIRS = new Set(["layouts", "states", "components", "blocks"]);

// ── find the rx root ──
const arg = process.argv[2];
const candidates = arg ? [resolve(arg)] : [resolve("apps/unoverse/rx"), resolve("rx")];
const RX = candidates.find(
  (p) => existsSync(join(p, "marketplace")) || existsSync(join(p, "components")) || existsSync(join(p, "atoms")),
);
if (!RX) {
  console.error("unoverse lint: cannot find an rx/ folder (looked for: " + candidates.join(", ") + ")");
  process.exit(2);
}

// ── tree layout ──
// New layout: rx/marketplace/{atoms,components,styles} + one top-level folder per
// org (rx/<org>/). Legacy layout: components/ + atoms/ at the root, orgs under rx/orgs/.
// The DESIGN SYSTEM is the primary lint target; org folders get the SAME generic
// checks — nothing here may key on a specific org's name.
const DS = existsSync(join(RX, "marketplace")) ? join(RX, "marketplace") : RX;
const legacyOrgsDir = join(RX, "orgs");
const orgDirs = (() => {
  if (existsSync(legacyOrgsDir))
    return readdirSync(legacyOrgsDir)
      .filter((e) => !e.startsWith("."))
      .map((e) => join(legacyOrgsDir, e))
      .filter((d) => statSync(d).isDirectory());
  if (DS === RX) return [];
  return readdirSync(RX)
    .filter((e) => !e.startsWith(".") && e !== "marketplace" && e !== "_schema")
    .map((e) => join(RX, e))
    .filter((d) => statSync(d).isDirectory());
})();

const problems = [];
const seen = new Set();
const report = (level, file, msg, line) => {
  const rel = relative(process.cwd(), file);
  const key = `${level}|${rel}|${line ?? ""}|${msg}`;
  if (seen.has(key)) return;
  seen.add(key);
  problems.push({ level, file: rel, line, msg });
};

// ── helpers ──
function jsonFiles(dir) {
  let out = [];
  if (!existsSync(dir)) return out;
  for (const f of readdirSync(dir)) {
    if (f.startsWith(".")) continue;
    const p = join(dir, f);
    if (statSync(p).isDirectory()) out = out.concat(jsonFiles(p));
    else if (isDefFile(f)) out.push(p);
  }
  return out;
}
const isFixture = (f) => /\.states\.(json|yaml)$/.test(f);
const isManifest = (f) => /^manifest\.(json|yaml)$/.test(basename(f));
const isTemplatePath = (f) => f.includes(`${sep}templates${sep}`);
// The DEFINITION ROOT folder for a file: a bare partial lives one level under it
// (layouts/ states/ components/ blocks/); every `$include` resolves against it.
const defRoot = (file) => {
  const dir = dirname(file);
  return PARTIAL_DIRS.has(basename(dir)) ? dirname(dir) : dir;
};

// The space scale — a bare numeric dimension value MUST be a real step, or the
// renderer passes it through as broken CSS and the element auto-sizes silently.
const DIMENSION_KEYS = new Set([
  "width", "height", "maxWidth", "minWidth", "minHeight", "maxHeight",
  "gap", "padding", "margin", "top", "right", "bottom", "left", "inset",
]);
const spaceSteps = new Set(["0", "full", "auto"]);
{
  const styleRoots = [defPath(join(DS, "styles", "base"), "spacing"), ...orgDirs.map((d) => defPath(join(d, "styles", "base"), "spacing"))].filter(Boolean);
  for (const f of styleRoots) {
    if (!existsSync(f)) continue;
    try {
      const space = readDef(f).space ?? {};
      for (const k of Object.keys(space)) if (!k.startsWith("$")) spaceSteps.add(k);
    } catch { /* linted on its own */ }
  }
}
const stepList = () => [...spaceSteps].filter((s) => /^\d/.test(s)).sort((a, b) => Number(a) - Number(b)).join(", ");
const checkDimension = (file, where, key, v) => {
  for (const raw of Array.isArray(v) ? v : [v]) {
    // A NUMBER is held to the same law as a numeric string — raw JSON numbers
    // (`"maxWidth": 560`) must not smuggle pixel values past the scale.
    const val = typeof raw === "number" ? String(raw) : raw;
    if (typeof val !== "string" || val.includes("{{")) continue;
    if (/^\d+(\.\d+)?$/.test(val) && spaceSteps.size > 3 && !spaceSteps.has(val))
      report("error", file, `${where}.${key}: "${val}" is not a step on the space scale — invalid values fall through as broken CSS (auto sizing). Real steps: ${stepList()} (docs/design/06)`);
  }
};

// atoms — case-insensitive by filename (the platform's lookup rule)
const atomsDirExists = existsSync(join(DS, "atoms"));
const atomNames = new Set(
  (atomsDirExists ? readdirSync(join(DS, "atoms")) : [])
    .filter(isDefFile)
    .map((f) => defName(f).toLowerCase()),
);

// A Ref resolves an atom OR a marketplace component (shared flat chrome like
// ComposerBar). Component folders are named by their id — collect them so a
// Ref to a shared component isn't flagged as a missing atom.
const dsComponentsDir = join(DS, "components");
const dsComponentNames = new Set(
  (existsSync(dsComponentsDir) ? readdirSync(dsComponentsDir, { withFileTypes: true }) : [])
    .filter((e) => !e.name.startsWith("."))
    .map((e) => (e.isDirectory() ? e.name : defName(e.name)).toLowerCase()),
);
// A valid Ref target if there's ANY resolvable home (atoms OR DS components).
const refResolves = (ref) => atomNames.has(ref.toLowerCase()) || dsComponentNames.has(ref.toLowerCase());

// definition homes: marketplace components/atoms + each org's templates AND
// components (same law everywhere — an org component is a component, just org-private)
const homes = [{ dir: join(DS, "components") }, { dir: join(DS, "atoms") }];
for (const orgDir of orgDirs) {
  for (const sub of ["templates", "components"]) {
    const d = join(orgDir, sub);
    if (existsSync(d) && statSync(d).isDirectory()) homes.push({ dir: d });
  }
}

// ── component-name uniqueness across tiers (the no-shadowing law) ──
// Names are the addressing contract: a bare `unoverse://components/<name>` must be
// unambiguous, so ONE name may exist in exactly one home (marketplace OR one org).
{
  const seenNames = new Map(); // lower-name -> first home path
  const componentHomes = [join(DS, "components")];
  for (const orgDir of orgDirs) {
    const d = join(orgDir, "components");
    if (existsSync(d) && statSync(d).isDirectory()) componentHomes.push(d);
  }
  for (const home of componentHomes) {
    if (!existsSync(home)) continue;
    for (const e of readdirSync(home)) {
      if (e.startsWith(".")) continue;
      const p = join(home, e);
      const name = (statSync(p).isDirectory() ? e : isDefFile(e) ? defName(e) : null)?.toLowerCase();
      if (!name) continue;
      const first = seenNames.get(name);
      if (first)
        report("error", p, `component name "${name}" already exists at ${relative(RX, first)} — names are UNIQUE across the marketplace and every org (no shadowing); rename one`);
      else seenNames.set(name, p);
    }
  }
}

// ── one DEFAULT app per org (the /mcp/<org> front door) ──
// Exactly one app is an org's home; a host opens the app whose manifest sets `default: true`
// as the conversation's entry point. Two defaults = ambiguous front door → error.
for (const orgDir of orgDirs) {
    const tdir = join(orgDir, "templates");
    if (!(existsSync(tdir) && statSync(tdir).isDirectory())) continue;
    const defaults = [];
    for (const e of readdirSync(tdir)) {
      const mf = defPath(join(tdir, e), "manifest");
      if (!existsSync(mf)) continue;
      try {
        if (readDef(mf).default === true) defaults.push(mf);
      } catch {
        /* malformed manifest is reported elsewhere */
      }
    }
    if (defaults.length > 1)
      for (const mf of defaults)
        report(
          "error",
          mf,
          `org "${org}" has ${defaults.length} apps with "default": true — an org has exactly ONE default app (its /mcp/${org} front door). Keep it on one manifest, remove it from the others (docs/unoverse/UNOVERSE_MCP_TEMPLATE_PROTOCOL.md §4b)`,
        );
  }

// ── condition (visibleWhen / style.when entry) ──
function checkCondition(vw, file, where) {
  if (typeof vw === "string") return; // bare truthy field
  if (vw && typeof vw === "object" && !Array.isArray(vw)) {
    if (typeof vw.field !== "string")
      report("error", file, `${where}: condition needs a "field" (docs/design/04)`);
    const extra = Object.keys(vw).filter((k) => !CONDITION_KEYS.has(k));
    if (extra.length)
      report("error", file, `${where}: illegal condition key(s) ${extra.join(", ")} — only eq/ne/in/truthy exist; no and/or/arithmetic (derive in the node) (docs/design/03)`);
    return;
  }
  report("error", file, `${where}: visibleWhen must be a field name or { field, eq|ne|in } (docs/design/04)`);
}

// ── per-node structural walk ──
// `widthCap` = the tightest numeric maxWidth on this node's ancestor chain (space
// steps are monotonic, so step names compare numerically).
// The org's STANDARD APP SIZES (styles/semantic/app-sizes.json) — the names `appWidth`
// may reference. null = the file is not under an org (no size home to check against).
const appSizesCache = new Map();
function appSizesForFile(file) {
  const m = file.match(/[\\/]orgs[\\/]([^\\/]+)[\\/]/);
  if (!m) return null;
  const org = m[1];
  if (!appSizesCache.has(org)) {
    const p = defPath(join(dirname(file).split(`${sep}orgs${sep}`)[0], "orgs", org, "styles", "semantic"), "app-sizes");
    let sizes = {};
    try {
      if (existsSync(p)) {
        const j = readDef(p);
        for (const [k, v] of Object.entries(j.appSize ?? {})) sizes[k] = typeof v === "string" ? v : v?.$value;
      }
    } catch {
      /* the file lints separately */
    }
    appSizesCache.set(org, sizes);
  }
  return appSizesCache.get(org);
}

// The universal component names (rx/components/*, case-insensitive) — for validating a
// template manifest's `preview` map. null = the file is not under an rx tree.
const componentNamesCache = new Map();
// Components an ORG's template may reference: the marketplace tier + that org's OWN
// components — never another org's (org-privacy). Cached per org.
function componentNamesForFile(file) {
  const m = file.split(`${sep}orgs${sep}`);
  if (m.length < 2) return null;
  const org = m[1].split(sep)[0];
  const cached = componentNamesCache.get(org);
  if (cached !== undefined) return cached;
  const dirs = [join(m[0], "components"), join(m[0], "orgs", org, "components")];
  let names = null;
  for (const dir of dirs) {
    if (!existsSync(dir)) continue;
    names ??= new Set();
    for (const e of readdirSync(dir)) names.add(defName(e).toLowerCase());
  }
  componentNamesCache.set(org, names);
  return names;
}

function walkNode(node, file, root, widthCap = null, isLayoutRoot = false) {
  if (Array.isArray(node)) return node.forEach((n) => walkNode(n, file, root, widthCap));
  if (!node || typeof node !== "object") return;

  // $include — resolves against the DEFINITION ROOT (layouts/ states/ components/…)
  if (typeof node.$include === "string") {
    const a = defPath(root, node.$include);
    const b = join(root, node.$include);
    if (!a && !existsSync(b))
      report("error", file, `$include "${node.$include}" does not resolve under ${relative(process.cwd(), root)}/ (docs/design/03)`);
    return; // the included file is linted on its own
  }

  const t = node.type;
  if (typeof t !== "string")
    report("error", file, `node without "type" (and no $include) — every node names a primitive (docs/design/02)`);
  else if (!PRIMITIVES.has(t))
    report("error", file, `unknown primitive "${t}" — the set is closed; compose, don't invent (docs/design/02)`);

  if (t === "Switch") {
    if (typeof node.on !== "string" || !node.cases || typeof node.cases !== "object")
      report("error", file, `Switch needs "on" (the discriminant field) + "cases" (docs/design/04)`);
    else
      for (const [caseKey, branch] of Object.entries(node.cases)) {
        const vw = branch && typeof branch === "object" ? branch.visibleWhen : undefined;
        const guarded = typeof vw === "string" ? vw : vw && typeof vw === "object" ? vw.field : null;
        if (guarded === node.on)
          report("error", file, `Switch on "${node.on}" → case "${caseKey}" re-guards its own discriminant — a layer never guards itself; delete the visibleWhen (docs/design/03)`);
      }
  }
  // Each: a `template` + a list — EITHER a literal `items:[]` (hardcoded content,
  // the microapp default) OR `bind.items` (a workflow-fed array).
  if (t === "Each") {
    const hasList = Array.isArray(node.items) || (node.bind && typeof node.bind === "object" && node.bind.items);
    if (!node.template || !hasList)
      report("error", file, `Each needs "template" + a list — literal "items": [...] or "bind": { "items": "<field>" } (docs/design/03)`);
  }
  if (t === "Ref") {
    if (typeof node.ref !== "string")
      report("error", file, `Ref needs "ref": "<atom name>" (docs/design/03)`);
    else if (atomsDirExists && !refResolves(node.ref))
      report("error", file, `Ref "${node.ref}" — no matching atom (rx/marketplace/atoms) or shared component (rx/marketplace/components); lookup is case-insensitive by name`);
  }
  if (t === "ComponentSlot") {
    if (!node.select || typeof node.select !== "object")
      report("error", file, `ComponentSlot needs "select" ({} for the conversation flow) (docs/design/05)`);
    else if (node.select.from === "all" && !node.select.type && !node.select.where)
      report("warn", file, `global ComponentSlot (from:"all") with no "type" and no "where" — selects OLDEST-first; a trap in a multi-turn surface. Filter by "where" (the reaction contract, §5b) or pin "type", unless the shell is deliberately catch-all (docs/design/05)`);
    // STATE-SELECTED UI (STATE_MODEL §5b): a reaction surface reacts to the component's
    // VIEW — the `defaultState` discriminant — never to a component's internal state
    // (step/phase/…) which is private to the component. Selecting on any other field
    // reaches past the view boundary the whole model rests on.
    else if (node.select.where && node.select.where.field && node.select.where.field !== "defaultState")
      report("warn", file, `reaction surface selects on "${node.select.where.field}" — a template reacts to a component's VIEW ("defaultState"), never its internal state (that is private to the component). Select on "defaultState" (STATE_MODEL §5b)`);
    // ONE STATE AT A TIME (docs/design/04): the active state is THE latest surfaced
    // view, so a surface must claim exactly ONE view by `eq` — `ne`/`in`/bare selects
    // make "which state is the template in?" ambiguous.
    else if (node.select.where && node.select.where.field === "defaultState" && typeof node.select.where.eq !== "string")
      report("error", file, `a reaction surface claims exactly ONE view: select.where needs "eq": "<view>" — ne/in/bare make the template's active state ambiguous (docs/design/04)`);
  }

  // STATE-OWNED SIZING (docs/design/05): every PANEL states its width once via
  // `appWidth`; the app is the sum of the open ones. A plain node = always open (the
  // core chat column); a reaction-surface ComponentSlot = open while occupied; a
  // visibleWhen pane = open while its condition matches.
  if (node.appWidth !== undefined) {
    if (typeof node.appWidth !== "string" || node.appWidth.trim() === "")
      report("error", file, `"appWidth" must be a CSS width string ("360px", "min(50vw, 760px)") or a named app size ("chat", "rail", "panel") (docs/design/05)`);
    // A bare name is a STANDARD SIZE — it must exist in the org's app-sizes.json
    // (rx/orgs/<org>/styles/semantic/app-sizes.json); the server resolves it at serve time.
    else if (/^[a-z][a-z0-9-]*$/i.test(node.appWidth)) {
      const sizes = appSizesForFile(file);
      if (sizes && !(node.appWidth in sizes))
        report("error", file, `"appWidth": "${node.appWidth}" names no app size — declare it in the org's styles/semantic/app-sizes.json (known: ${Object.keys(sizes).join(", ") || "none"}) (docs/design/05)`);
    }
    if (t === "ComponentSlot" && !(node.select && node.select.where))
      report("error", file, `"appWidth" on a ComponentSlot without select.where — only a reaction surface can slide out; the flow slot never sizes the app (docs/design/05)`);
    // ONE declaration per panel: the SDK sizes the frame FROM appWidth (width +
    // flex: 0 0 auto) — a frame width/flex alongside it is dead duplication that
    // can silently disagree.
    if (t === "ComponentSlot" && node.frame && node.frame.style) {
      for (const dup of ["width", "flex"])
        if (node.frame.style[dup] !== undefined)
          report("error", file, `panel frame declares style.${dup} alongside appWidth — the panel states its width ONCE; the SDK sizes the frame from appWidth. Remove the frame ${dup} (docs/design/05)`);
    }
  }

  // BRIEFED COMPONENTS (the composer): a `brief` sits on the node that renders what it
  // describes and compiles into the component's MCP tool schema (server briefSchema →
  // registry metadata.inputSchema → the minted tool). Shape is a closed contract —
  // a typo'd key or misplaced constraint silently weakens the compiled schema.
  if (node.brief !== undefined) {
    const b = node.brief;
    if (typeof b !== "string" && (typeof b !== "object" || b === null || Array.isArray(b)))
      report("error", file, `"brief" must be a string (the description) or { description, maxLength | minItems/maxItems } (docs/design/03)`);
    else if (typeof b === "object") {
      // description/maxLength/minItems/maxItems COMPILE into the tool inputSchema. `hydrate` is a
      // NON-schema brief annotation (a hydration hook naming what to hydrate) — a valid brief key
      // that does NOT compile into the schema; allowed here so it doesn't read as a typo.
      const BRIEF_KEYS = new Set(["description", "maxLength", "minItems", "maxItems", "hydrate"]);
      for (const k of Object.keys(b))
        if (!BRIEF_KEYS.has(k))
          report("error", file, `brief.${k} is not part of the brief contract — only description / maxLength / minItems / maxItems (schema) or hydrate (hydration hook) are allowed (docs/design/03)`);
      if (b.description !== undefined && typeof b.description !== "string")
        report("error", file, `brief.description must be a string — it IS the schema field's description (docs/design/03)`);
      if (b.hydrate !== undefined && typeof b.hydrate !== "string")
        report("error", file, `brief.hydrate must be a string (names the field/source to hydrate) (docs/design/03)`);
      for (const nk of ["maxLength", "minItems", "maxItems"])
        if (b[nk] !== undefined && (typeof b[nk] !== "number" || b[nk] < 0 || !Number.isInteger(b[nk])))
          report("error", file, `brief.${nk} must be a non-negative integer — it compiles to the native JSON Schema keyword (docs/design/03)`);
      if (typeof b.minItems === "number" && typeof b.maxItems === "number" && b.minItems > b.maxItems)
        report("error", file, `brief.minItems (${b.minItems}) > maxItems (${b.maxItems}) — no composition can satisfy this schema (docs/design/03)`);
      const bound = node.bind && (node.bind.value || node.bind.src);
      const isEach = t === "Each" && node.bind && node.bind.items;
      if (b.maxLength !== undefined && !bound)
        report("warn", file, `brief.maxLength on a node with no bind — a length cap only compiles when the brief sits next to the bound field it governs (docs/design/03)`);
      if ((b.minItems !== undefined || b.maxItems !== undefined) && !isEach)
        report("warn", file, `brief.minItems/maxItems on a non-Each node — item counts only compile on the Each that binds the array (docs/design/03)`);
    }
  }

  if (node.visibleWhen !== undefined) checkCondition(node.visibleWhen, file, t || "node");

  // deprecated FOCUS BRIDGE (STATE_MODEL §5b): nothing writes a template `defaultState`
  // key anymore — a component writes only its own slice; templates react via select.where.
  // (Legit panel/draft setTemplateValue writes a DIFFERENT key and is untouched.)
  const scanAction = (a) => {
    if (!a || typeof a !== "object") return;
    if (a.type === "setTemplateValue") {
      // A COMPONENT writes only its own slice — ANY template-state write from the
      // shared component home is the deprecated bridge (STATE_MODEL §5b). Template-
      // local partials (composer, suggestions) legitimately write template chrome.
      if (!isTemplatePath(file))
        report("error", file, `a component never writes template state — setTemplateValue is the deprecated bridge; change the view with setValue and let the template react via select.where (STATE_MODEL §5b)`);
      else if (Array.isArray(a.values) && a.values.some((v) => v && v.key === "defaultState"))
        report("warn", file, `setTemplateValue writing "defaultState" is the deprecated focus bridge — a component writes only its own slice; templates react via ComponentSlot.select.where (STATE_MODEL §5b)`);
    }
    if (a.then) scanAction(a.then);
  };
  if (node.action) scanAction(node.action);

  // style — closed KEY vocabulary + real space-scale VALUES (both cross-platform contracts)
  if (node.style && typeof node.style === "object") {
    // a container query the element's own layout can never satisfy — the threshold is
    // at/above an ancestor's maxWidth cap, so visibility is decided by the HOST surface,
    // not the design (shows in a wide studio stage, vanishes in a chat column)
    const mw = node.style.maxWidth;
    if (typeof mw === "string" && /^\d+$/.test(mw))
      widthCap = widthCap == null ? Number(mw) : Math.min(widthCap, Number(mw));
    const hb = node.style.hideBelow;
    if (typeof hb === "string" && /^\d+$/.test(hb) && widthCap != null && Number(hb) >= widthCap)
      report("warn", file, `hideBelow "${hb}" ≥ an ancestor maxWidth "${widthCap}" — the query can only be satisfied by the surrounding surface, so visibility depends on the host, not the card; lower the threshold below the card's own max width (docs/design/06)`);
    const checkKeys = (obj, where) => {
      for (const k of Object.keys(obj)) {
        if (k === "when") continue; // validated below
        if (!STYLE_KEYS.has(k))
          report("error", file, `${where}: unknown style key "${k}" — the style vocabulary is closed (the cross-platform contract). Typo, or a web-ism that won't port (docs/design/06)`);
        else if ((k === "hover" || k === "active") && obj[k] && typeof obj[k] === "object")
          checkKeys(obj[k], `${where}.${k}`);
        else if (DIMENSION_KEYS.has(k)) checkDimension(file, where, k, obj[k]);
      }
    };
    checkKeys(node.style, `${t}.style`);
    // style.when = [{ field, eq|ne|in?, apply:{…} }, …]
    if (node.style.when !== undefined) {
      const w = node.style.when;
      if (!Array.isArray(w))
        report("error", file, `${t}.style.when must be an array of { field, eq|ne|in, apply } entries (docs/design/04)`);
      else
        for (const e of w) {
          if (!e || typeof e !== "object" || typeof e.field !== "string" || !e.apply)
            report("error", file, `${t}.style.when entry needs "field" + "apply" (docs/design/04)`);
          else {
            const extra = Object.keys(e).filter((k) => !CONDITION_KEYS.has(k) && k !== "apply");
            if (extra.length)
              report("error", file, `${t}.style.when: illegal key(s) ${extra.join(", ")} — conditions are eq/ne/in/truthy only (docs/design/04)`);
            if (typeof e.apply === "object") checkKeys(e.apply, `${t}.style.when.apply`);
          }
        }
    }
  }

  for (const key of CHILD_NODE_KEYS) if (node[key] !== undefined) walkNode(node[key], file, root, widthCap);
  if (t === "Switch" && node.cases && typeof node.cases === "object")
    for (const branch of Object.values(node.cases)) walkNode(branch, file, root, widthCap);
}

// ── stateOrder ⇄ states/ folder cross-check ──
function checkStateOrder(order, rootFolder, file, includeLayouts = false) {
  if (!Array.isArray(order)) return;
  const dirNames = (sub) => {
    const d = join(rootFolder, sub);
    return existsSync(d)
      ? readdirSync(d).filter(isDefFile).map(defName)
      : [];
  };
  // TEMPLATES: stateOrder lists LOCAL states + LAYOUTS in picker order (docs/design/05) —
  // a layout name (the view a component enters) is a valid entry. COMPONENTS: states only.
  const stateNames = dirNames("states");
  const onDisk = new Set([...stateNames, ...(includeLayouts ? dirNames("layouts") : [])]);
  for (const name of order)
    if (typeof name === "string" && !onDisk.has(name))
      report("error", file, `stateOrder lists "${name}" but no states/${name}${includeLayouts ? ` or layouts/${name}` : ""} definition exists (docs/design/${includeLayouts ? "05" : "03"})`);
  // Only STATES must appear in stateOrder to lock the picker order; the default layout is
  // legitimately omitted, so never warn on layouts.
  for (const name of stateNames)
    if (!order.includes(name))
      report("warn", file, `states/${name}.json is not in stateOrder — it falls to the end of the picker; add it to lock the order (docs/design/07)`);
}

// ── lint one file ──
function lintFile(file) {
  const src = readFileSync(file, "utf8");

  // LAW 1 — tokens only (skip manifest + fixture; styles/ is never in a def home).
  // Exempt: `appWidth` — the HOST-facing outer width (state-owned sizing, docs/design/05).
  // It is raw CSS the embed host applies to the app panel ("min(50vw, 760px)", "360px"),
  // never a style the SDK resolves — token law governs the inside, not the envelope.
  if (!isFixture(file) && !isManifest(file))
    src.split("\n").forEach((line, i) => {
      if (RAW_VALUE.test(line) && !/^\s*"?appWidth"?\s*:/.test(line))
        report("error", file, `raw value — token names only; add/scale a token in the org styles instead (LAW 1, docs/design/06): ${line.trim()}`, i + 1);
    });

  let json;
  try {
    json = parseDef(src, file);
  } catch (e) {
    report("error", file, `invalid ${file.endsWith(".yaml") ? "YAML" : "JSON"}: ${e.message}`);
    return;
  }

  if (isFixture(file)) return; // legacy fixture, unused — don't choke

  if (isManifest(file)) {
    const root = dirname(file);
    if (isTemplatePath(file)) {
      // TEMPLATE manifest = the envelope. Requires binding + a resolvable root.
      for (const req of ["name", "whenToUse"])
        if (!json[req]) report("warn", file, `template manifest missing "${req}" — ${req === "whenToUse" ? "the AI selects the app by it" : "the display name"} (docs/design/05)`);
      if (!(json.binding && json.binding.workflow))
        report("warn", file, `template manifest has no binding.workflow — the app owns its workflow binding (docs/design/05)`);
      // Two valid roots (definitions.ts:229): the STANDARD manifest-only form (root =
      // layouts/<layout>), OR a `<name>` envelope OVERRIDE (its own root). Only the
      // manifest-only form must resolve a layout; an envelope-form template supplies its own.
      const hasEnvelope = !!defPath(root, basename(root));
      if (!hasEnvelope) {
        const layoutName = json.layout ?? "main";
        if (!defPath(join(root, "layouts"), layoutName))
          report("error", file, `manifest.layout "${layoutName}" → layouts/${layoutName} does not exist (and no <name> envelope) (docs/design/05)`);
      }
      checkStateOrder(json.stateOrder, root, file, /* includeLayouts */ true);
      // ONE STATE AT A TIME (docs/design/04): the active state is derived from the
      // latest surfaced VIEW, so no two surfaces in one template may claim the same
      // view — the active surface would be ambiguous.
      {
        const claims = new Map(); // view -> first file
        const collectClaims = (n, from) => {
          if (Array.isArray(n)) return n.forEach((c) => collectClaims(c, from));
          if (!n || typeof n !== "object") return;
          const w = n.type === "ComponentSlot" ? n.select?.where : null;
          if (w?.field === "defaultState" && typeof w.eq === "string") {
            if (claims.has(w.eq))
              report("error", file, `two reaction surfaces claim the view "${w.eq}" (${claims.get(w.eq)} and ${from}) — a template is in ONE state at a time; each view has exactly one surface (docs/design/04)`);
            else claims.set(w.eq, from);
          }
          for (const v of Object.values(n)) if (v && typeof v === "object") collectClaims(v, from);
        };
        for (const sub of ["layouts", "states", "components"]) {
          const d = join(root, sub);
          if (!existsSync(d)) continue;
          for (const f of readdirSync(d).filter(isDefFile)) {
            try {
              collectClaims(readDef(join(d, f)), `${sub}/${f}`);
            } catch {
              /* that file lints separately */
            }
          }
        }
      }
      if (json.mode !== undefined && json.defaultState === undefined)
        report("warn", file, `"mode" was renamed to "defaultState" — still read as a fallback, but rename it (docs/design/04)`);
      // `preview` — the per-state MOCK map ({ "<state>": ["coursecard", …] }): each key
      // must be a states/ file, each name a real component. A repeated name seeds
      // several instances (a card rail).
      if (json.preview !== undefined) {
        if (!json.preview || typeof json.preview !== "object" || Array.isArray(json.preview))
          report("error", file, `"preview" must be an object mapping state names to component-name arrays (docs/design/07)`);
        else {
          // preview keys are per-LAYOUT (the component view Studio mocks) or a local state
          // (docs/design/05) — resolve against states/ ∪ layouts/, same as stateOrder.
          const viewsIn = (sub) => {
            const d = join(root, sub);
            return existsSync(d)
              ? readdirSync(d).filter(isDefFile).map(defName)
              : [];
          };
          const states = new Set([...viewsIn("states"), ...viewsIn("layouts")]);
          const comps = componentNamesForFile(file);
          for (const [state, list] of Object.entries(json.preview)) {
            if (!states.has(state))
              report("error", file, `preview."${state}" — no states/${state}.json or layouts/${state}.json in this template (docs/design/07)`);
            if (!Array.isArray(list) || list.some((c) => typeof c !== "string")) {
              report("error", file, `preview."${state}" must be an array of component names`);
              continue;
            }
            for (const c of list)
              if (comps && !comps.has(String(c).toLowerCase()))
                report("error", file, `preview."${state}" names unknown component "${c}" — no match in rx/components/ or this org's components/ (org-privacy: another org's components are out of reach; lookup is case-insensitive)`);
          }
        }
      }
      // Sizing is STATE-OWNED (docs/design/05): the layout root's `appWidth` is the core
      // surface's constant width; a panel slot's `appWidth` slides out on top. Manifest
      // width/focusWidth are DEAD — nothing reads them; there is no fallback.
      for (const dep of ["width", "focusWidth"])
        if (json[dep] !== undefined)
          report("error", file, `manifest "${dep}" is dead — nothing reads it. Sizing is state-owned: \`appWidth\` on the layout root (constant core width) or on a panel (slide-out width) (docs/design/05)`);
    } else {
      // COMPONENT manifest = OPTIONAL spatial discovery. No binding. Mirrors the
      // discovery-meta assertions in server/src/runtime/microapp-structure.test.ts.
      const desc = typeof json.description === "string" ? json.description.trim() : "";
      if (desc.length < 20)
        report("error", file, `discovery manifest.description missing/too short — one line (≥20 chars) saying what the component IS (docs/design/03a)`);
      else if (desc.length > 120)
        report("error", file, `discovery manifest.description is ${desc.length} chars — it's the listing subtitle (≤120); move detail into whenToUse (docs/design/03a)`);
      const wtu = typeof json.whenToUse === "string" ? json.whenToUse.trim() : "";
      if (wtu.length < 20)
        report("error", file, `discovery manifest.whenToUse missing/too short — the utterance-shaped selection text findIntent ranks on (docs/design/03a)`);
      else if (/\b(pick when|use (this|when)|when the user|the user (asks|wants|needs)|select (this|when))\b/i.test(wtu))
        report("error", file, `discovery manifest.whenToUse is selector-shaped — write the words the USER would say, not instructions about the user (docs/design/03a)`);
      if (json.binding)
        report("warn", file, `a component discovery manifest has no workflow — drop "binding" (a component is streamed or node-hydrated) (docs/design/03a)`);
      // `lifetime` — OPTIONAL render lifetime (docs/design/04 §Two lifetimes). Closed set:
      // "turn" (default — the universal new-turn reset) | "conversation" (durable
      // conversation-scoped surface: conversation-keyed instance, exempt from the
      // new-turn reset, retired only by replacement, self-close, or a template swap).
      if (json.lifetime !== undefined && json.lifetime !== "turn" && json.lifetime !== "conversation")
        report("error", file, `manifest "lifetime" must be "turn" (default) or "conversation" — got ${JSON.stringify(json.lifetime)} (docs/design/04 §Two lifetimes)`);
    }
    return;
  }

  const isEnvelope = typeof json.unoverse === "string";
  const root = defRoot(file);

  if (isEnvelope) {
    // COMPONENT envelope (templates have no envelope — their manifest is it).
    for (const req of ["kind", "name", "root"])
      if (json[req] === undefined) report("error", file, `envelope missing "${req}" (docs/design/02)`);
    if (json.kind && !["component", "template", "atom"].includes(json.kind))
      report("error", file, `unknown kind "${json.kind}"`);
    if (json.kind === "component" && !json.category)
      report("warn", file, `component has no "category" — used to group it in the palette (docs/design/02)`);
    if (json.root) walkNode(json.root, file, root);

    // ── the contained-microapp discipline (mirrors microapp-structure.test.ts) ──
    if (json.kind === "component") {
      const hasLayouts = existsSync(join(root, "layouts"));
      const statesDir = join(root, "states");
      const stateFiles = existsSync(statesDir)
        ? readdirSync(statesDir).filter(isDefFile).map(defName).sort()
        : [];
      const hasStateBlock = json.state && typeof json.state === "object";

      // the discovery manifest is the single home for description/whenToUse — no dup
      if (defPath(root, "manifest"))
        for (const k of ["description", "whenToUse"])
          if (json[k] !== undefined)
            report("error", file, `envelope duplicates manifest meta "${k}" — the discovery manifest is the single home (docs/design/03a)`);

      // deprecated bridge: a top-level `defaultState` triggers the component node TEMPLATE_DATA emit
      if (json.defaultState !== undefined)
        report("warn", file, `top-level "defaultState" is the deprecated bridge (component-node TEMPLATE_DATA emit) — the master state lives in the \`state\` block; templates react via ComponentSlot.select.where (STATE_MODEL §5b)`);

      // only components that ADOPTED the structure are held to the full discipline
      if (hasLayouts || stateFiles.length || hasStateBlock) {
        const nonInput = Object.entries(json.props ?? {})
          .filter(([, v]) => !(v && typeof v === "object" && v.input === true))
          .map(([k]) => k);
        if (nonInput.length)
          report("error", file, `microapp props [${nonInput.join(", ")}] are not input:true — hardcode content in the layout, or move mutable keys into the \`state\` block (docs/design/03)`);

        // the state block holds SCALAR internal view-state ONLY — an array/object (a
        // finder's result rows) or a URL is content/data slop: hardcode it in the layout,
        // or move workflow-fed data to props (input:true) (AUTHORING §3)
        if (hasStateBlock)
          for (const [k, v] of Object.entries(json.state)) {
            if (Array.isArray(v) || (v && typeof v === "object"))
              report("error", file, `state.${k} is an ${Array.isArray(v) ? "array" : "object"} — the state block is SCALAR view-state only; workflow-fed data → props (input:true), static content → hardcode in the layout (docs/design/03)`);
            else if (typeof v === "string" && /^https?:\/\//.test(v))
              report("error", file, `state.${k} is a URL — content, not view-state; hardcode it in the layout (or props input:true if workflow-fed) (docs/design/03)`);
          }

        if (hasLayouts) {
          const raw = JSON.stringify(json.root ?? {}).replace(/\s/g, "");
          if (!raw.includes('"on":"defaultState"') || !/"\$include":"layouts\//.test(raw))
            report("error", file, `a faced component's root must Switch on defaultState → $include layouts/<state> (the layout filename = the state name, e.g. layouts/inline) (docs/design/03)`);

          // ── face set ⇄ layouts/ cross-check (OPEN name set — inline/focused/<any>) ──
          // The FACES are the root Switch's cases; Studio's face toggle and the render
          // path both derive from them, so cases and layout files must agree exactly.
          const findFaceSwitch = (n) => {
            if (!n || typeof n !== "object") return null;
            if (Array.isArray(n)) { for (const c of n) { const r = findFaceSwitch(c); if (r) return r; } return null; }
            if (n.type === "Switch" && n.on === "defaultState" && n.cases && typeof n.cases === "object") return n;
            for (const v of Object.values(n)) { const r = findFaceSwitch(v); if (r) return r; }
            return null;
          };
          const faceSwitch = findFaceSwitch(json.root);
          if (faceSwitch) {
            const cases = faceSwitch.cases;
            const caseNames = Object.keys(cases).filter((k) => k !== "default");
            // inline is the UNIVERSAL default face: an unknown/absent defaultState must
            // render SOMETHING — require an `inline` case or an explicit `default`.
            // EXCEPTION — a SURFACE-ONLY component (docs/design/03): its manifest
            // declares a SURFACED arrival (defaultState naming one of its cases, not
            // inline), and it deliberately renders NOTHING while unsurfaced (e.g. a
            // rail card retired by a new turn). Then omitting inline/default is the
            // point, not a mistake.
            if (!caseNames.includes("inline") && cases.default === undefined) {
              let arrival;
              try {
                const mp = defPath(root, "manifest");
                if (mp) arrival = readDef(mp).defaultState;
              } catch { /* linted separately */ }
              const surfaceOnly = typeof arrival === "string" && arrival !== "inline" && caseNames.includes(arrival);
              if (!surfaceOnly)
                report("error", file, `faced component's Switch has no "inline" case and no "default" — inline is the universal default face; a component with neither disappears for unknown states. (Intentional surface-only component? Declare a surfaced arrival: manifest.defaultState naming one of its cases.) (STATE_MODEL §5b)`);
            }
            // Each named case's layout include must MATCH the case name — the layout
            // filename IS the state name (Studio writes defaultState=<case>).
            const usedLayouts = new Set();
            for (const [name, body] of Object.entries(cases)) {
              const inc = body && typeof body === "object" ? body.$include : undefined;
              if (typeof inc !== "string" || !inc.startsWith("layouts/")) continue;
              const layoutName = inc.slice("layouts/".length);
              usedLayouts.add(layoutName);
              if (name !== "default" && layoutName !== name)
                report("error", file, `face case "${name}" includes layouts/${layoutName} — the layout FILENAME is the state name; rename one so they match (docs/design/03)`);
            }
            // Orphan faces: a layouts/*.json no case references is invisible — Studio's
            // face toggle and the renderer only know the Switch's cases.
            const layoutsDir = join(root, "layouts");
            if (existsSync(layoutsDir))
              for (const lf of readdirSync(layoutsDir).filter(isDefFile)) {
                const lname = defName(lf);
                if (!usedLayouts.has(lname))
                  report("warn", file, `layouts/${lf} is not referenced by any Switch case — an orphan face is unreachable (add a case "${lname}" or delete the file) (docs/design/03)`);
              }
          }
          // arrival state: the manifest is the render-contract home (default "inline"); the
          // state block is the legacy fallback.
          let mDefault;
          try {
            const mp = defPath(root, "manifest");
            if (mp) mDefault = readDef(mp).defaultState;
          } catch { /* linted separately */ }
          const arrival = mDefault ?? (hasStateBlock ? json.state.defaultState : undefined);
          if (typeof arrival !== "string")
            report("error", file, `a faced component must declare its arrival state in manifest.defaultState (the render contract) or state.defaultState (docs/design/03)`);
        }
        if (stateFiles.length) {
          const order = Array.isArray(json.stateOrder) ? [...json.stateOrder].sort() : null;
          if (!order || !order.length)
            report("error", file, `has states/ but no stateOrder in the envelope (docs/design/03)`);
          else if (JSON.stringify(order) !== JSON.stringify(stateFiles))
            report("error", file, `stateOrder and states/*.json must name the same set (docs/design/03)`);
        }
      }
    } else {
      checkStateOrder(json.stateOrder, root, file); // non-component envelopes (rare)
    }
  } else {
    // bare partial (layouts/ states/ components/ blocks/, or an atom). A template
    // layout's TOP-LEVEL node is the app's layout root — the one non-slot home for
    // `appWidth` (state-owned sizing, docs/design/05).
    walkNode(json, file, root, null, /[\\/]layouts[\\/][^\\/]+\.(json|yaml)$/.test(file) && isTemplatePath(file));
  }
}

// ── run ──
for (const home of homes) for (const f of jsonFiles(home.dir)) lintFile(f);

const by = (lvl) => problems.filter((p) => p.level === lvl);
const icon = { error: "✗", warn: "⚠", hint: "·" };
for (const p of problems) console.log(`${icon[p.level]} ${p.file}${p.line ? ":" + p.line : ""}  ${p.msg}`);
console.log(`\nunoverse lint: ${by("error").length} error(s), ${by("warn").length} warning(s), ${by("hint").length} hint(s) — ${homes.map((h) => relative(process.cwd(), h.dir)).join(", ")}`);
process.exit(by("error").length ? 1 : 0);
