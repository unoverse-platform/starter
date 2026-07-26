#!/usr/bin/env node
/**
 * unoverse lint nodes — the declarative node linter.
 *
 * Sibling of lint.mjs (which lints rx/). Same contract: errors fail (exit 1),
 * warnings and hints inform, and every message cites the owning doc.
 *
 * FOUR TIERS (docs/architecture/DECLARATIVE_NODES.md §6). This file is tiers 2 and 3.
 *   1  editor        $schema pointers + .vscode yaml.schemas — free, no tool
 *   2  structural    every part validated against nodes/_schema/*.json
 *   3  semantic      the CROSS-FILE rules a schema cannot express, below
 *   4  dry run       `unoverse node test` — executes against testData, not here
 *
 * Unlike lint.mjs this is NOT dependency-free: it needs a YAML parser and a JSON
 * Schema validator, and hand-rolling either is the kind of silently-wrong that is
 * worse than no check at all.
 *
 * Usage: node lint-nodes.mjs [path-to-nodes]   (default: ./apps/unoverse/nodes)
 */
import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";
import { join, relative, resolve, dirname } from "node:path";
import { createRequire } from "node:module";

const require_ = createRequire(import.meta.url);
let YAML, Validator;
try {
  YAML = require_("yaml");
  ({ Validator } = require_("@cfworker/json-schema"));
} catch {
  console.error("unoverse lint nodes needs two packages:\n\n  npm install -D yaml @cfworker/json-schema\n");
  process.exit(1);
}

const NODES_HOME = resolve(process.argv[2] || "./apps/unoverse/nodes");
if (!existsSync(NODES_HOME)) {
  console.error(`No nodes directory at ${NODES_HOME}`);
  process.exit(1);
}
const SCHEMA_DIR = join(NODES_HOME, "_schema");

// ── schemas ───────────────────────────────────────────────────────────────────
const schemas = {};
if (existsSync(SCHEMA_DIR))
  for (const f of readdirSync(SCHEMA_DIR).filter((f) => f.endsWith(".json")))
    try {
      const s = JSON.parse(readFileSync(join(SCHEMA_DIR, f), "utf8"));
      schemas[s.$id] = s;
    } catch (e) {
      console.error(`_schema/${f} is not valid JSON: ${e.message}`);
      process.exit(1);
    }

const SCHEMA_ID = {
  node: "https://unoverse/nodes/node.schema.json",
  interface: "https://unoverse/nodes/interface.schema.json",
  config: "https://unoverse/nodes/config.schema.json",
  api: "https://unoverse/nodes/api.schema.json",
  test: "https://unoverse/nodes/test.schema.json",
  package: "https://unoverse/nodes/package.schema.json",
  credential: "https://unoverse/nodes/credential.schema.json",
};

/** The four sections that may live in their own file OR inline in node.yaml. */
const SECTIONS = ["interface", "config", "api", "test"];

// ── reporting ─────────────────────────────────────────────────────────────────
const problems = [];
const report = (level, file, msg) => problems.push({ level, file, msg });
/** Shortest readable form: a walk out of the tree is worse than the absolute path. */
const rel = (p) => {
  const r = relative(process.cwd(), p);
  return r.startsWith("..") || r.length >= p.length ? p : r;
};

// ── loading ───────────────────────────────────────────────────────────────────
function readYaml(file) {
  try {
    const doc = YAML.parse(readFileSync(file, "utf8"));
    if (doc && typeof doc === "object") delete doc.$schema;
    return doc ?? {};
  } catch (e) {
    report("error", rel(file), `is not valid YAML: ${e.message.split("\n")[0]}`);
    return null;
  }
}

/**
 * Resolve `{ $ref: "../../shared/models.yaml#/enum" }` in place.
 *
 * Only a lone $ref is a reference — an object that merely HAS a $ref alongside
 * other keys is data, and silently replacing it would lose those keys.
 */
function resolveRefs(value, baseDir, file, seen = new Set()) {
  if (Array.isArray(value)) return value.map((v) => resolveRefs(v, baseDir, file, seen));
  if (!value || typeof value !== "object") return value;

  const keys = Object.keys(value);
  if (keys.length === 1 && typeof value.$ref === "string") {
    const [target, frag = ""] = value.$ref.split("#");
    const abs = resolve(baseDir, target);
    if (seen.has(value.$ref)) {
      report("error", file, `$ref cycle at "${value.$ref}"`);
      return null;
    }
    if (!existsSync(abs)) {
      report("error", file, `$ref "${value.$ref}" points at a file that does not exist`);
      return null;
    }
    const doc = readYaml(abs);
    if (doc === null) return null;
    const hit = frag
      .replace(/^\//, "")
      .split("/")
      .filter(Boolean)
      .reduce((a, k) => (a == null ? a : a[k]), doc);
    if (hit === undefined) {
      report("error", file, `$ref "${value.$ref}" resolved to nothing — check the fragment path`);
      return null;
    }
    // Count distinct CONSUMERS, not $ref sites: one config.yaml referencing a
    // fragment twice (enum + enumNames) is still a single consumer.
    if (!refCounts.has(abs)) refCounts.set(abs, new Set());
    refCounts.get(abs).add(file);
    return resolveRefs(hit, dirname(abs), file, new Set([...seen, value.$ref]));
  }
  return Object.fromEntries(keys.map((k) => [k, resolveRefs(value[k], baseDir, file, seen)]));
}
const refCounts = new Map();

// ── structural validation ─────────────────────────────────────────────────────
function validateAgainst(schemaId, doc, file, label) {
  const schema = schemas[schemaId];
  if (!schema) {
    report("warn", file, `no schema found for ${label} — is nodes/_schema/ present?`);
    return;
  }
  const v = new Validator(schema, "7", false);
  for (const [id, s] of Object.entries(schemas)) if (id !== schemaId) v.addSchema(s, id);
  const r = v.validate(doc);
  if (r.valid) return;
  // A single bad value produces one error per schema level plus internal artefacts.
  // Keep only the DEEPEST error per location: that is the one naming the real problem.
  const useful = r.errors.filter(
    (e) => !/False boolean schema|does not match additional properties|A subschema had errors|does not match schema\.$/.test(e.error),
  );
  const deepest = new Map();
  for (const e of useful.length ? useful : r.errors) {
    const at = e.instanceLocation.replace(/^#/, "") || "(root)";
    if (!deepest.has(at)) deepest.set(at, e.error);
  }
  for (const [at, err] of [...deepest].slice(0, 6)) report("error", file, `${at} ${err} (${label})`);
}

// ── one node ──────────────────────────────────────────────────────────────────
function lintNode(dir, pkg) {
  const nodePath = join(dir, "node.yaml");
  const label = rel(dir);

  if (!existsSync(nodePath))
    return report("error", label, `has no node.yaml — it is the one REQUIRED file in a node folder (DECLARATIVE_NODES.md §5)`);

  const node = readYaml(nodePath);
  if (!node) return;

  // Each section: its own file, or inline in node.yaml, NEVER both. Silently
  // merging the two would make a stale file invisible.
  const parts = {};
  for (const s of SECTIONS) {
    const file = join(dir, `${s}.yaml`);
    const onDisk = existsSync(file);
    const inline = node[s] !== undefined;
    if (onDisk && inline) {
      report("error", rel(file), `"${s}" is defined BOTH in ${s}.yaml and inline in node.yaml — pick one; this is never a merge (DECLARATIVE_NODES.md §5)`);
      continue;
    }
    if (onDisk) parts[s] = { doc: readYaml(file), file: rel(file) };
    else if (inline) parts[s] = { doc: node[s], file: rel(nodePath) };
  }
  for (const s of SECTIONS) if (parts[s]) delete node[s];

  // Resolve $refs into shared/ before anything reads a value.
  for (const s of SECTIONS)
    if (parts[s]?.doc) parts[s].doc = resolveRefs(parts[s].doc, dir, parts[s].file);

  // ── tier 2: structure ──
  validateAgainst(SCHEMA_ID.node, node, rel(nodePath), "node.schema.json");
  for (const s of SECTIONS) if (parts[s]?.doc) validateAgainst(SCHEMA_ID[s], parts[s].doc, parts[s].file, `${s}.schema.json`);

  const iface = parts.interface?.doc ?? {};
  const config = parts.config?.doc ?? null;
  const api = parts.api?.doc ?? null;
  const test = parts.test?.doc ?? null;
  const F = { node: rel(nodePath), iface: parts.interface?.file, config: parts.config?.file, api: parts.api?.file, test: parts.test?.file };

  const outputs = new Set((iface.outputs ?? []).map((o) => o.name));
  const inputs = new Set((iface.inputs ?? []).map((i) => i.name));

  // A PURE SERVICE node legitimately has no outputs: it is never triggered by the
  // graph, it answers callers and hands them a value. Any other node with no outputs
  // cannot be wired to anything.
  if (!outputs.size && !api?.provides)
    report("error", F.iface ?? F.node, `declares no outputs — a node that emits nothing cannot be wired to anything`);

  // The service channel must match what the node advertises. A method with no
  // connector is undiscoverable; a connector method with no implementation is a lie
  // that only surfaces when a consumer calls it (08-mcp-services.md).
  if (api?.provides || (iface.serviceConnectors ?? []).some((s) => s.isService === true)) {
    const advertised = new Set(
      (iface.serviceConnectors ?? []).filter((s) => s.isService === true).flatMap((s) => s.methods ?? []),
    );
    for (const method of Object.keys(api?.provides ?? {}))
      if (!advertised.has(method))
        report("error", F.api, `provides "${method}" but no serviceConnector with isService: true lists it in methods — nothing can discover it`);
    for (const method of advertised)
      if (!api?.provides?.[method])
        report("error", F.iface ?? F.node, `advertises method "${method}" but api.yaml provides no implementation — a consumer calling it gets an error`);
  }

  // ── tier 3: semantics ──

  // kind is DECLARED but VERIFIED. Getting it wrong used to surface only at runtime.
  // A tool exchange is a multi-turn LOOP, so it makes the node a CallbackNode just as
  // surely as a streaming transport does, and it must name a connector that grants tools.
  // Tools reach a node through an mcp serviceConnector it CONSUMES. Declaring a tool
  // exchange without one means the request would carry an empty tools array.
  if (api?.toolExchange) {
    const consumes = (iface.serviceConnectors ?? []).filter((s) => s.serviceType === "mcp" && s.isService === false);
    if (!consumes.length)
      report(
        "error",
        F.iface ?? F.node,
        `declares a toolExchange but no serviceConnector with serviceType: mcp and isService: false — there is nothing to source tools from`,
      );
  }

  if (api?.response) {
    const streaming = ["sse", "ndjson", "awsEventStream"].includes(api.response.transport);
    const continuePort = (iface.inputs ?? []).some((i) => ["CONTINUE", "SPAWN"].includes(i.signal));
    const derived = streaming || continuePort || api.toolExchange ? "CallbackNode" : "PromiseNode";
    if (node.kind && node.kind !== derived) {
      const why = streaming
        ? `transport "${api.response.transport}" streams`
        : api.toolExchange
          ? `it declares a toolExchange, which is a multi-turn loop`
          : `an input declares a ${continuePort ? "CONTINUE/SPAWN" : ""} signal`;
      report("error", F.node, `kind is "${node.kind}" but this node is a ${derived}: ${why} (DECLARATIVE_NODES.md §5)`);
    }
    derivedKinds.set(label, derived);

    // Transport and response shape have to agree.
    if (streaming && !(api.response.events ?? []).length)
      report("error", F.api, `transport "${api.response.transport}" streams but declares no response.events — nothing would ever be emitted`);
    if (!streaming && api.response.events)
      report("error", F.api, `transport "${api.response.transport}" settles once, so response.events is meaningless — use response.map`);
    if (!streaming && !api.response.map && api.response.transport !== "binary")
      report("warn", F.api, `transport "${api.response.transport}" has no response.map — nothing maps onto this node's outputs`);
    if (!streaming && api.response.finalize)
      report("error", F.api, `response.finalize belongs to a streaming transport; a settling one has only response.map`);
  } else if (existsSync(join(dir, "src")) === false && !parts.api) {
    report("warn", F.node, `has no api.yaml — a manifest node with no upstream call does nothing`);
  }

  // Every emit target must be a declared output, or it goes nowhere silently.
  for (const e of api?.response?.events ?? [])
    if (!outputs.has(e.emit))
      report("error", F.api, `event "${e.match}" emits to "${e.emit}", which is not a declared output (interface.yaml)`);
  if (api?.response?.finalize && !outputs.has(api.response.finalize.emit))
    report("error", F.api, `response.finalize emits to "${api.response.finalize.emit}", which is not a declared output (interface.yaml)`);
  for (const k of Object.keys(api?.response?.map ?? {}))
    if (!outputs.has(k)) report("error", F.api, `response.map targets "${k}", which is not a declared output (interface.yaml)`);

  // An output nothing emits to is dead: downstream nodes can wire to it and get nothing.
  const emitted = new Set([
    ...(api?.response?.events ?? []).map((e) => e.emit),
    ...Object.keys(api?.response?.map ?? {}),
    api?.response?.finalize?.emit,
  ].filter(Boolean));
  if (api) for (const o of outputs) if (!emitted.has(o)) report("warn", F.iface ?? F.node, `output "${o}" is declared but nothing emits to it`);

  // Credentials must resolve to a declared type, or the run fails at execute time.
  for (const c of iface.credentials ?? []) {
    const name = c.name;
    if (!pkg.credentials.has(name))
      report("error", F.iface ?? F.node, `needs credential "${name}" but no credentials/${name}.yaml exists in this package — a package DECLARES the credentials it needs (04-credentials.md)`);
  }

  // configSchema internal consistency.
  if (config?.configSchema) {
    const props = config.configSchema.properties ?? {};
    const names = Object.keys(props);
    for (const r of config.configSchema.required ?? [])
      if (!names.includes(r)) report("error", F.config, `required names "${r}", which is not a property`);

    const order = config["ui:order"] ?? [];
    for (const f of order) if (!names.includes(f)) report("error", F.config, `ui:order names "${f}", which is not a property`);
    if (order.length) for (const p of names) if (!order.includes(p)) report("warn", F.config, `property "${p}" is missing from ui:order — it renders last, in an arbitrary place`);

    for (const [n, f] of Object.entries(props)) {
      if (f.enum && f.enumNames && f.enum.length !== f.enumNames.length)
        report("error", F.config, `${n}: enum has ${f.enum.length} values but enumNames has ${f.enumNames.length} — they are positionally parallel`);
      if (f.enum && f.default !== undefined && !f.enum.includes(f.default))
        report("error", F.config, `${n}: default "${f.default}" is not one of its enum values`);
      for (const dep of Object.keys(f["ui:dependencies"] ?? {}))
        if (!names.includes(dep)) report("error", F.config, `${n}: ui:dependencies names "${dep}", which is not a sibling property`);
      // A template field on an object/array takes a `return` expression, not handlebars.
      if (f["ui:field"] === "template" && (f.type === "object" || f.type === "array") && typeof f.default === "string" && f.default.trim() && !f.default.startsWith("return "))
        report("warn", F.config, `${n}: is an object template, so its value is a "return ..." expression, not handlebars (06-config-schema.md)`);
    }

    // Every {{ config.x }} in the request must name a real config field.
    if (api)
      for (const ref of [...JSON.stringify(api).matchAll(/\{\{[~\s]*(?:[#\/]?\w+\s+)?(?:\(\w+\s+)?config\.([A-Za-z0-9_]+)/g)].map((m) => m[1]))
        if (!names.includes(ref)) report("error", F.api, `templates {{ config.${ref} }} but "${ref}" is not a config property`);
  }

  // A template naming an unregistered helper compiles and then throws at run time.
  // The registered set lives in engine/src/template/StringTemplateResolver.ts.
  //
  // Scan ONLY inside {{ }}. The rest of an api.yaml holds `return ...` expressions
  // whose arrow callbacks — filter(e => ...) — read exactly like a subexpression.
  if (api) {
    const seen = new Set();
    for (const [, body] of JSON.stringify(api).matchAll(/\{\{([^}]*)\}\}/g)) {
      const helpers = [
        ...[...body.matchAll(/^[~\s]*[#\/]([a-zA-Z][\w]*)/g)].map((m) => m[1]), // {{#if}} {{/if}}
        ...[...body.matchAll(/\(([a-zA-Z][\w]*)\s/g)].map((m) => m[1]), // (eq a b)
      ];
      for (const h of helpers)
        if (!HANDLEBARS_HELPERS.has(h) && !seen.has(h)) {
          seen.add(h);
          report("error", F.api, `template uses helper "${h}", which is not registered (engine/src/template/StringTemplateResolver.ts) — it throws at run time, not at build time`);
        }
      // {{prompt.x}} / {{blocks.x}} must name a real block, else it resolves to
      // EMPTY and the instruction just silently vanishes from the prompt.
      for (const [, b] of body.matchAll(/\b(?:prompt|blocks)\.([A-Za-z0-9_]+)/g))
        if (!PROMPT_BLOCKS.has(b) && !seen.has(b)) {
          seen.add(b);
          report("error", F.api, `references prompt block "{{prompt.${b}}}", which does not exist in prompts/blocks/ — it resolves to empty and the instruction silently disappears`);
        }
    }
  }

  // A node nobody can run is a node nobody can trust.
  if (!test?.testData) {
    report("error", F.node, `has no testData — every node needs sample data so it can be loaded and run (DECLARATIVE_NODES.md §6)`);
  } else {
    if (config?.configSchema) {
      const v = new Validator(config.configSchema, "7", false);
      const r = v.validate(test.testData.config ?? {});
      for (const e of r.errors.filter((e) => e.instanceLocation !== "#").slice(0, 4))
        report("error", F.test, `testData.config${e.instanceLocation.replace(/^#/, "")} ${e.error} — the sample must satisfy this node's own configSchema`);
    }
    for (const k of Object.keys(test.testData.inputs ?? {}))
      if (!inputs.has(k)) report("error", F.test, `testData.inputs has "${k}", which is not a declared input`);
    // On the workflow channel an expect key names an output connector. On the SERVICE
    // channel there are no connectors: the method hands back one value, so the keys are
    // just labels for the assertions over it.
    const call = test.testData.call;
    if (!call)
      for (const k of Object.keys(test.testData.expect ?? {}))
        if (!outputs.has(k)) report("error", F.test, `testData.expect has "${k}", which is not a declared output`);

    if (call && !api?.provides?.[call.method])
      report("error", F.test, `testData.call names method "${call.method}", which api.yaml does not provide`);
    if (!call && api?.provides && !api?.request)
      report("error", F.test, `this node only provides service methods, so testData needs a "call" block naming one — otherwise nothing can run it`);
  }

  // whenToUse decides whether the node SURFACES to the building agent at all.
  const w = (node.whenToUse ?? "").trim();
  if (w) {
    if (/^use this (node|when)/i.test(w))
      report("warn", F.node, `whenToUse opens by restating itself — lead with the OUTCOME in task vocabulary (14-node-discoverability.md)`);
    if (/^(hybrid|attach|this is an?|a powerful)/i.test(w))
      report("warn", F.node, `whenToUse opens with plumbing or marketing — outcome first, mechanism last; it sinks the ranking (14-node-discoverability.md)`);
    if (node.description && w.toLowerCase() === node.description.toLowerCase())
      report("error", F.node, `whenToUse merely repeats description — it carries zero selection signal (14-node-discoverability.md)`);
  }

  // EGRESS. A manifest cannot execute, but it can say "send this credential to
  // evil.example". SECURITY.md bounds a code node by provenance and a template
  // expression by having no credentials in scope; a manifest node is neither, so the
  // declared host list is its boundary. Deny by default, and catch it statically here
  // as well as at run time.
  if (api?.request?.url) {
    const literal = String(api.request.url).replace(/\{\{[^}]*\}\}/g, " ");
    let host = null;
    try {
      host = new URL(literal.replace(/ /g, "x")).host.toLowerCase();
    } catch {
      report("error", F.api, `request.url is not a valid URL: ${api.request.url}`);
    }
    if (host) {
      if (!/^https:/i.test(literal))
        report("error", F.api, `request.url is not https — a credential must not travel in clear text`);
      const egress = pkg.egress ?? [];
      const templated = literal.includes(" ");
      const ok = egress.some((p) =>
        p.startsWith("*.")
          ? host.endsWith(p.slice(1)) && !host.slice(0, -(p.length - 1)).includes(".")
          : host === p,
      );
      if (!egress.length)
        report("error", rel(pkg.file), `node ${node.type} makes a request but package.yaml declares no egress — a package with no declared hosts cannot call out at all`);
      else if (!ok && !templated)
        report("error", rel(pkg.file), `node ${node.type} calls "${host}" but package.yaml egress is ${egress.map((e) => `"${e}"`).join(", ")} — declare it or the executor will refuse the request`);
    }
  }

  // The package must promise every executor capability its nodes name, or deploy
  // to an older executor lints clean and fails at run time.
  if (pkg.requires && api) {
    const scheme = api.request?.auth?.scheme;
    if (scheme && scheme !== "none" && !(pkg.requires.auth ?? []).includes(scheme))
      report("error", rel(pkg.file), `node ${node.type} uses auth "${scheme}" but package.yaml requires.auth does not list it`);
    const t = api.response?.transport;
    if (t && !(pkg.requires.transport ?? []).includes(t))
      report("error", rel(pkg.file), `node ${node.type} uses transport "${t}" but package.yaml requires.transport does not list it`);
  }

  return node;
}
const derivedKinds = new Map();

/**
 * Every credential declared anywhere, name -> { file, fields }.
 *
 * A credential is declared BY THE PACKAGE that needs it (04-credentials.md), so the
 * same name can legitimately appear in several packages. What is not legitimate is
 * two packages disagreeing about its FIELDS: context.credentials is one flat bag
 * keyed by name, so the second declaration would describe a credential the first
 * cannot read.
 */
const allCredentials = new Map();

/**
 * The prompt-block library: prompts/blocks/**\/*.md, keyed the way the resolver keys
 * them (engine/src/template/promptBlocks.ts) — the filename camelCased, so
 * markdown-guidelines.md is referenced as {{prompt.markdownGuidelines}}.
 *
 * A manifest must never hold a COPY of a block's words: that is a fork that silently
 * stops tracking the block. It references, and this checks the reference resolves.
 */
const PROMPT_BLOCKS = (() => {
  const found = new Map();
  const home = resolve(NODES_HOME, "../prompts/blocks");
  const walk = (d) => {
    if (!existsSync(d)) return;
    for (const e of readdirSync(d)) {
      const p = join(d, e);
      if (statSync(p).isDirectory()) walk(p);
      else if (e.endsWith(".md")) {
        const id = e.replace(/\.md$/, "");
        found.set(id.replace(/-([a-z])/g, (_, c) => c.toUpperCase()), rel(p));
      }
    }
  };
  walk(home);
  return found;
})();

/**
 * Handlebars built-ins plus the helpers the platform registers in
 * engine/src/template/StringTemplateResolver.ts. Anything else compiles fine and
 * then throws when the node actually runs, which is the worst place to find out.
 */
const HANDLEBARS_HELPERS = new Set([
  "if", "unless", "each", "with", "lookup", "log", "else", // built-in
  "toJSON", "filter", "eq", "contains", // registered
]);

// ── one package ───────────────────────────────────────────────────────────────
function lintPackage(dir) {
  const pkgFile = join(dir, "package.yaml");
  const pkg = { file: pkgFile, credentials: new Set(), requires: null, egress: [] };

  if (existsSync(pkgFile)) {
    const doc = readYaml(pkgFile);
    if (doc) {
      validateAgainst(SCHEMA_ID.package, doc, rel(pkgFile), "package.schema.json");
      pkg.requires = doc.requires ?? null;
      pkg.egress = (doc.egress ?? []).map((h) => String(h).toLowerCase());
      if (doc.name && doc.name !== dir.split("/").pop())
        report("warn", rel(pkgFile), `name "${doc.name}" does not match the folder name "${dir.split("/").pop()}"`);
    }
  }

  const credDir = join(dir, "credentials");
  if (existsSync(credDir))
    for (const f of readdirSync(credDir).filter((f) => /\.ya?ml$/.test(f))) {
      const doc = readYaml(join(credDir, f));
      if (!doc) continue;
      validateAgainst(SCHEMA_ID.credential, doc, rel(join(credDir, f)), "credential.schema.json");
      if (doc.name) pkg.credentials.add(doc.name);
      if (doc.name && doc.name !== f.replace(/\.ya?ml$/, ""))
        report("warn", rel(join(credDir, f)), `declares name "${doc.name}" but the file is ${f} — nodes reference the NAME, so keep them the same`);

      // Two packages may both declare a credential, but they must agree on it:
      // context.credentials is ONE flat bag keyed by name, so a disagreement means
      // whichever package loses the race describes a credential it cannot read.
      if (doc.name) {
        const fields = (doc.properties ?? []).map((p) => p.name).sort().join(",");
        const prior = allCredentials.get(doc.name);
        if (prior && prior.fields !== fields)
          report(
            "error",
            rel(join(credDir, f)),
            `credential "${doc.name}" is also declared in ${prior.file} with different fields (${prior.fields} vs ${fields}) — they share one entry in context.credentials and must agree (04-credentials.md)`,
          );
        else if (!prior) allCredentials.set(doc.name, { file: rel(join(credDir, f)), fields });
      }
    }

  // MIGRATION HAZARD, checked per package because the credential's NAME often is not
  // in this package's source at all (openai re-exports OpenAICredential from
  // plugin-base, so only the identifier appears here).
  //
  // registerCredentialType is first-wins-and-SILENT: it logs "already registered,
  // skipping" and returns. With a credentials/*.yaml AND a live api.registerCredential
  // call, whichever loads first takes the slot and the other vanishes. A wrong
  // credential type then makes getDecryptedCredential quietly skip decryption, which
  // surfaces as an auth failure with the right credential visibly selected.
  if (pkg.credentials.size) {
    const entry = join(dir, "src/index.ts");
    if (existsSync(entry) && /api\.registerCredential\s*\(/.test(readFileSync(entry, "utf8")))
      report(
        "error",
        rel(entry),
        `still calls api.registerCredential() while this package also declares credentials/ manifests — registration is first-wins and silent, so one of them is dropped at random. Move the declaration, do not copy it (04-credentials.md)`,
      );
  }

  const nodesDir = join(dir, "nodes");
  if (!existsSync(nodesDir)) return 0;

  let count = 0;
  const types = new Map();
  for (const entry of readdirSync(nodesDir)) {
    const nd = join(nodesDir, entry);
    if (!statSync(nd).isDirectory()) continue;
    const node = lintNode(nd, pkg);
    count++;
    if (node?.type) {
      if (types.has(node.type))
        report("error", rel(nd), `type "${node.type}" is already used by ${types.get(node.type)} — a node type is a stable global identity`);
      else types.set(node.type, entry);
      if (node.type !== entry)
        report("warn", rel(nd), `folder is "${entry}" but type is "${node.type}" — keep them the same so a type is findable by path`);
    }
  }

  // A shared/ fragment with one consumer should be inlined; shared/ is for DATA
  // several nodes genuinely share, and it silts up if nothing prunes it.
  const sharedDir = join(dir, "shared");
  if (existsSync(sharedDir))
    for (const f of readdirSync(sharedDir).filter((f) => /\.ya?ml$/.test(f))) {
      const n = refCounts.get(join(sharedDir, f))?.size ?? 0;
      if (n === 0) report("warn", rel(join(sharedDir, f)), `is referenced by nothing — delete it or $ref it`);
      else if (n === 1) report("hint", rel(join(sharedDir, f)), `has a single consumer — a fragment earns shared/ at the SECOND one, otherwise inline it`);
    }

  return count;
}

// ── run ───────────────────────────────────────────────────────────────────────
let nodeCount = 0, pkgCount = 0;
for (const entry of readdirSync(NODES_HOME)) {
  const dir = join(NODES_HOME, entry);
  if (entry.startsWith("_") || entry.startsWith(".") || !statSync(dir).isDirectory()) continue;
  if (!existsSync(join(dir, "nodes")) && !existsSync(join(dir, "package.yaml"))) continue; // pure code package
  pkgCount++;
  nodeCount += lintPackage(dir);
}

const by = (lvl) => problems.filter((p) => p.level === lvl);
const icon = { error: "✗", warn: "⚠", hint: "·" };
const rank = { error: 0, warn: 1, hint: 2 };
for (const p of problems.sort((a, b) => rank[a.level] - rank[b.level] || a.file.localeCompare(b.file)))
  console.log(`${icon[p.level]} ${p.file}  ${p.msg}`);

if (derivedKinds.size) {
  console.log("");
  for (const [n, k] of derivedKinds) console.log(`  ${k.padEnd(13)} ${n}`);
}

console.log(
  `\nunoverse lint nodes: ${by("error").length} error(s), ${by("warn").length} warning(s), ${by("hint").length} hint(s)` +
    ` — ${nodeCount} node(s) in ${pkgCount} package(s), ${rel(NODES_HOME) || NODES_HOME}`,
);
process.exit(by("error").length ? 1 : 0);
