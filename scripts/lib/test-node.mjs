#!/usr/bin/env node
/**
 * unoverse node test — tier 4 of the node checks (DECLARATIVE_NODES.md §6).
 *
 * The other three tiers are static: the editor, the schemas, and the cross-file
 * rules. This one RUNS the node, against its own test.yaml, hitting the real API.
 * It is the only check that can tell you the manifest describes the service
 * correctly rather than merely describing something coherently.
 *
 * Credentials come from the developer's own .env, never from a store this tool
 * invents (LOCAL_STUDIO.md). Nothing is written anywhere.
 *
 * Usage: node test-node.mjs <NodeType> [path-to-nodes]
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, join } from "node:path";

const [, , NODE_TYPE, NODES_ARG] = process.argv;
if (!NODE_TYPE) {
  console.error("Usage: unoverse node test <NodeType>");
  process.exit(1);
}
const NODES_HOME = resolve(NODES_ARG || "./apps/unoverse/nodes");

// .env, the way a developer already keeps secrets. Never overwrite a real env var.
for (const f of [".env", ".env.local"]) {
  const p = resolve(f);
  if (!existsSync(p)) continue;
  for (const line of readFileSync(p, "utf8").split("\n")) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].trim().replace(/^["']|["']$/g, "");
  }
}

const S = "apps/unoverse/server/src/runtime";
const { loadManifests, getManifestNode } = await import(resolve(`${S}/manifests/index.js`));
const { performApi, performProvided, emptyContext, applyResolvers, evaluate } = await import(resolve(`${S}/manifests/runtime/index.js`));

const { errors } = await loadManifests();
for (const e of errors) console.warn(`⚠ ${e}`);

const node = getManifestNode(NODE_TYPE);
if (!node) {
  console.error(`\nNo manifest node "${NODE_TYPE}" found in ${NODES_HOME}.`);
  process.exit(1);
}
if (!node.api) {
  console.error(`\n"${NODE_TYPE}" has no api.yaml, so there is nothing to run.`);
  process.exit(1);
}

const testData = node.definition.testData;
if (!testData?.config) {
  console.error(`\n"${NODE_TYPE}" has no testData.config — every node needs sample data so it can be run.`);
  process.exit(1);
}

// Credentials by declared name, from .env. Matches the local-Studio convention:
// <CREDENTIAL>_<FIELD> upper-snake, e.g. OPENAI_API_KEY.
const credentials = {};
const missing = [];
for (const decl of node.definition.credentials ?? []) {
  const base = decl.name.replace(/Credentials?$/i, "").toUpperCase();
  const credFile = join(NODES_HOME, node.packageName, "credentials", `${decl.name}.yaml`);
  const fields = existsSync(credFile)
    ? [...readFileSync(credFile, "utf8").matchAll(/^\s*-\s*name:\s*(\w+)/gm)].map((m) => m[1])
    : ["apiKey"];
  const bag = {};
  for (const field of fields) {
    const snake = field.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toUpperCase();
    const value = process.env[`${base}_${snake}`] ?? process.env[`${base}${snake}`];
    if (value) bag[field] = value;
  }
  credentials[decl.name] = bag;
  if (decl.required !== false && !Object.keys(bag).length) missing.push(`${base}_${fields[0].replace(/([a-z0-9])([A-Z])/g, "$1_$2").toUpperCase()}`);
}
if (missing.length) {
  console.error(`\nMissing from your .env: ${missing.join(", ")}`);
  process.exit(1);
}

const ctx = emptyContext({
  config: applyResolvers(testData.config, node),
  credentials,
  signal: testData.inputs ?? {},
});

const call = testData.call;
if (call && !node.api.provides?.[call.method]) {
  console.error(`\ntestData.call names "${call.method}" but api.yaml provides ${Object.keys(node.api.provides ?? {}).join(", ") || "nothing"}.`);
  process.exit(1);
}
if (!call && !node.api.request) {
  console.error(`\n"${NODE_TYPE}" only provides service methods. testData needs a "call" block naming one.`);
  process.exit(1);
}

const spec = call ? node.api.provides[call.method] : node.api;
console.log(`\n${node.definition.name}  (${node.packageName}/${node.type}, ${node.kind})`);
console.log(
  call
    ? `${spec.request.method} ${spec.request.url}   service call: ${call.method}\n`
    : `${spec.request.method} ${spec.request.url}   transport: ${spec.request.transport}\n`,
);

// SHOW the sample data. A bench that silently uses a fixture leaves you guessing what
// it actually ran with, which is the same as having no fixture at all.
console.log("── sample data (test.yaml) ──");
for (const [k, v] of Object.entries(ctx.config)) {
  const s = typeof v === "string" ? v : JSON.stringify(v);
  console.log(`  ${k.padEnd(18)} ${s.length > 68 ? s.slice(0, 67) + "…" : s}`);
}
for (const [k, v] of Object.entries(testData.inputs ?? {}))
  console.log(`  ${("in:" + k).padEnd(18)} ${JSON.stringify(v).slice(0, 68)}`);
if (call) console.log(`  ${"call".padEnd(18)} ${call.method}(${JSON.stringify(call.params ?? {}).slice(0, 50)})`);
for (const decl of node.definition.credentials ?? [])
  console.log(`  ${("cred:" + decl.name).padEnd(18)} ${Object.keys(credentials[decl.name] ?? {}).join(", ") || "(none found)"}`);
console.log("");

const counts = {};
const started = Date.now();
let result;
try {
  if (call) {
    // A service call hands back ONE value, so there is nothing to stream and nothing
    // emitted; the returned object stands in for `outputs`.
    result = { outputs: await performProvided(node, call.method, call.params ?? {}, ctx) };
  } else {
    result = await performApi(node, ctx, (e) => {
      counts[e.emit] = (counts[e.emit] ?? 0) + 1;
      if (e.emit === "stream" && typeof e.value === "string") process.stdout.write(e.value);
    });
  }
} catch (err) {
  console.error(`\n\n✗ ${err.message}\n`);
  process.exit(1);
}

console.log(`\n\n── emitted ──`);
for (const [k, n] of Object.entries(counts)) console.log(`  ${k.padEnd(12)} ${n} event(s)`);

console.log(`── outputs ──`);
const declared = new Set(call ? [] : (node.definition.outputs ?? []).map((o) => o.name));
for (const [k, v] of Object.entries(result.outputs)) {
  const s = typeof v === "string" ? v : JSON.stringify(v);
  console.log(`  ${k.padEnd(12)} ${(s ?? "").slice(0, 90)}${(s?.length ?? 0) > 90 ? "…" : ""}`);
  declared.delete(k);
}
// An output can be live without being an output VALUE: a streamed one is delivered
// event by event and never settles. Say which, rather than calling it empty.
for (const d of declared)
  console.log(`  ${d.padEnd(12)} ${counts[d] ? `(streamed only, ${counts[d]} event(s))` : "(nothing emitted)"}`);

// testData.expect: assertions over what actually came back.
let failed = 0;
if (testData.expect) {
  console.log(`── expect ──`);
  for (const [output, expr] of Object.entries(testData.expect)) {
    let pass = false;
    try {
      pass = !!(await evaluate(expr, { output: result.outputs }));
    } catch (err) {
      console.log(`  ✗ ${output}: expression failed — ${err.message}`);
      failed++;
      continue;
    }
    console.log(`  ${pass ? "✓" : "✗"} ${output}  ${expr}`);
    if (!pass) failed++;
  }
}

console.log(`\n${failed ? "✗" : "✓"} ${node.type} ran in ${Date.now() - started}ms${failed ? `, ${failed} assertion(s) failed` : ""}\n`);
process.exit(failed ? 1 : 0);
