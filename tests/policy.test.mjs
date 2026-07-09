// Unit tests for core/policy.mjs against the shared parity vectors in core/vectors.json.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { isWorkEmail, urlIsWork, isCommitCommand } from "../core/policy.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const vectors = JSON.parse(readFileSync(join(__dirname, "../core/vectors.json"), "utf8"));

let pass = 0, fail = 0;
function ok(cond, label) {
  if (cond) { console.log(`PASS: ${label}`); pass++; }
  else { console.log(`FAIL: ${label}`); fail++; }
}

for (const v of vectors.workEmails) ok(isWorkEmail(v), `workEmail: ${v}`);
for (const v of vectors.nonWorkEmails) ok(!isWorkEmail(v), `nonWorkEmail: ${v}`);
for (const v of vectors.workUrls) ok(urlIsWork(v), `workUrl: ${v}`);
for (const v of vectors.nonWorkUrls) ok(!urlIsWork(v), `nonWorkUrl: ${v}`);
for (const v of vectors.commitCommands) ok(isCommitCommand(v), `commitCommand: ${v}`);
for (const v of vectors.nonCommitCommands) ok(!isCommitCommand(v), `nonCommitCommand: ${v}`);

console.log("----");
console.log(`pass=${pass} fail=${fail}`);
process.exit(fail === 0 ? 0 : 1);
