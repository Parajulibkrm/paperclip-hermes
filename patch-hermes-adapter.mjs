// Patches NousResearch/hermes-paperclip-adapter#2 in the installed package.
//
// Released versions (≤ v0.3.0) of hermes-paperclip-adapter do not inject
// ctx.authToken into the spawned hermes child as PAPERCLIP_API_KEY, so every
// agent curl to the Paperclip API returns 401. Upstream main has the fix
// (PR #4) but it has not shipped to npm. We patch the compiled
// dist/server/execute.js in place after `npm install -g paperclipai`.
//
// Idempotent: detects the fix (either the upstream form or our injected
// line) and exits cleanly — once a fixed release lands on npm, this turns
// into a no-op.

import { execSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";

const ROOT = "/usr/local/lib/node_modules";
const TARGET = "*/hermes-paperclip-adapter/dist/server/execute.js";
const MARKER = "env.PAPERCLIP_TASK_ID = taskId;";
const INJECT =
  "    if (ctx.authToken && !env.PAPERCLIP_API_KEY) env.PAPERCLIP_API_KEY = ctx.authToken;";

const found = execSync(`find ${ROOT} -path "${TARGET}"`, { encoding: "utf8" })
  .split("\n")
  .filter(Boolean);

if (found.length === 0) {
  console.error(`[patch-hermes-adapter] execute.js not found under ${ROOT}`);
  process.exit(1);
}

for (const file of found) {
  const src = readFileSync(file, "utf8");

  if (/PAPERCLIP_API_KEY\s*=\s*(?:ctx\.)?authToken/.test(src)) {
    console.log(`[patch-hermes-adapter] already patched: ${file}`);
    continue;
  }

  if (!src.includes(MARKER)) {
    console.error(`[patch-hermes-adapter] marker not found in ${file}`);
    process.exit(1);
  }

  writeFileSync(file, src.replace(MARKER, `${MARKER}\n${INJECT}`));
  console.log(`[patch-hermes-adapter] applied to ${file}`);
}
