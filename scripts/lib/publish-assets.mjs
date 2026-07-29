#!/usr/bin/env node
/**
 * unoverse publish <project> — push a project's assets into a universe.
 *
 * The terminal face of `packages/base/src/items/publish.ts`. Studio will call the same
 * functions from a button; this file only formats and asks.
 *
 * The order is the safety: LINT, then COMPARE, then confirm, then send. Nothing leaves the
 * machine until the rules pass, because a developer should learn about a raw hex value from
 * their own terminal, not from an HTTP error. The universe validates again on receipt, as
 * it must not trust a client, but by then it is a second opinion rather than the only one.
 *
 * Usage:
 *   publish-assets.mjs <project> --to <universe> --token <jwt>   [--dry-run] [--yes]
 */
import { resolve, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createInterface } from "node:readline/promises";

const here = dirname(fileURLToPath(import.meta.url));
const base = join(here, "../../packages/base/src/items");
const { collectProject, listProjects } = await import(join(base, "collect.ts"));
const { lintForPublish, planPublish, sendPublish } = await import(join(base, "publish.ts"));

const arg = (name) => {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
};
const flag = (name) => process.argv.includes(`--${name}`);

const project = process.argv[2] && !process.argv[2].startsWith("--") ? process.argv[2] : undefined;
const universe = arg("to");
const token = arg("token") ?? process.env.UNOVERSE_TOKEN;
const rxHome = resolve(arg("rx") ?? "apps/unoverse/rx");

const c = { dim: "\x1b[2m", red: "\x1b[31m", green: "\x1b[32m", yellow: "\x1b[33m", bold: "\x1b[1m", off: "\x1b[0m" };
const die = (msg) => {
  console.error(`\n  ${c.red}✗${c.off} ${msg}\n`);
  process.exit(1);
};

if (!project) {
  const projects = listProjects(rxHome);
  die(`which project?\n\n    unoverse publish <project> --to <universe>\n\n  Found: ${projects.join(", ") || "none"}`);
}
if (!universe) die("no universe. Pass --to https://your-universe.com");
if (!token) die("no credential. Pass --token, or set UNOVERSE_TOKEN");

// ── 1. lint. Nothing is sent if this fails ────────────────────────────────────
console.log(`\n  ${c.bold}publish ${project}${c.off} ${c.dim}→ ${universe}${c.off}\n`);
process.stdout.write(`  ${c.dim}checking…${c.off}`);
const { problems, errors } = await lintForPublish(rxHome, project);
process.stdout.write("\r                    \r");

if (errors.length) {
  console.error(`  ${c.red}✗ ${errors.length} error(s) in ${project}. Nothing was sent.${c.off}\n`);
  for (const p of errors.slice(0, 10)) console.error(`    ${p.file}${p.line ? ":" + p.line : ""}  ${p.msg}`);
  if (errors.length > 10) console.error(`    ${c.dim}…and ${errors.length - 10} more${c.off}`);
  console.error("");
  process.exit(1);
}
const warnings = problems.filter((p) => p.level === "warn").length;
console.log(`  ${c.green}✓${c.off} checks passed${warnings ? ` ${c.dim}(${warnings} warning(s))${c.off}` : ""}`);

// ── 2. compare against what the universe already holds ────────────────────────
const items = collectProject(rxHome, project);
if (!items.length) die(`nothing to publish in ${project}`);

let plan;
try {
  plan = await planPublish(items, universe, token);
} catch (e) {
  die(e.message);
}

const line = (label, list, colour) =>
  list.length && console.log(`  ${colour}${String(list.length).padStart(3)}${c.off} ${label.padEnd(10)} ${c.dim}${list.map((i) => i.name).join(", ")}${c.off}`);

console.log("");
line("new", plan.create, c.green);
line("updated", plan.update, c.yellow);
line("unchanged", plan.unchanged, c.dim);
line("refused", plan.refused, c.red);
for (const r of plan.refused) console.log(`      ${c.red}${r.name}${c.off} ${c.dim}${r.why}${c.off}`);

const toSend = plan.create.length + plan.update.length;
if (!toSend) {
  console.log(`\n  ${c.green}✓${c.off} nothing to do, ${project} is up to date\n`);
  process.exit(0);
}
if (flag("dry-run")) {
  console.log(`\n  ${c.dim}dry run: ${toSend} item(s) would be sent${c.off}\n`);
  process.exit(0);
}

// ── 3. confirm, unless told not to ────────────────────────────────────────────
if (!flag("yes")) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const answer = await rl.question(`\n  Publish ${toSend} item(s) to ${universe}? [y/N] `);
  rl.close();
  if (!/^y(es)?$/i.test(answer.trim())) {
    console.log(`  ${c.dim}cancelled${c.off}\n`);
    process.exit(0);
  }
}

// ── 4. send ───────────────────────────────────────────────────────────────────
const { sent, failed } = await sendPublish(plan, universe, token);
console.log("");
for (const s of sent) console.log(`  ${c.green}✓${c.off} ${s.mode ?? "sent"} ${c.dim}${s.kind}/${s.name}${c.off}`);
for (const f of failed) console.log(`  ${c.red}✗${c.off} ${f.kind}/${f.name}  ${f.why}`);
console.log(
  `\n  ${failed.length ? c.red + "✗" : c.green + "✓"}${c.off} ${sent.length} published` +
    (failed.length ? `, ${failed.length} failed` : "") + "\n",
);
process.exit(failed.length ? 1 : 0);
