// Tests bridges/rewrite-check.mjs's runRewrite against the live rtk-rewrite.sh hook.
// No sibling policy.mjs dependency, so import directly from the repo path.
import { execSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, "..");

process.env.TVS_RTK_REWRITE = join(REPO_ROOT, "guards", "rtk-rewrite.sh");

const { runRewrite } = await import(join(REPO_ROOT, "bridges", "rewrite-check.mjs"));

let pass = 0;
let fail = 0;

function hasRtk() {
  try {
    execSync("which rtk", { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

if (hasRtk()) {
  const res = await runRewrite("git status");
  if (res.command === "rtk git status") {
    console.log("PASS: git status -> rtk git status");
    pass++;
  } else {
    console.log(`FAIL: git status rewrite — got ${JSON.stringify(res)}`);
    fail++;
  }
} else {
  const res = await runRewrite("git status");
  if (res.command === null) {
    console.log("SKIP (rtk absent): git status -> null, PASS");
    pass++;
  } else {
    console.log(`FAIL: expected null with rtk absent — got ${JSON.stringify(res)}`);
    fail++;
  }
}

// unspawnable rewrite path never throws
process.env.TVS_RTK_REWRITE = join(REPO_ROOT, "does-not-exist.sh");
const { runRewrite: runRewrite2 } = await import(
  join(REPO_ROOT, "bridges", "rewrite-check.mjs") + "?cachebust=" + Date.now()
);
{
  let threw = false;
  let res;
  try {
    res = await runRewrite2("git status");
  } catch {
    threw = true;
  }
  if (!threw && res && res.command === null) {
    console.log("PASS: unspawnable rewrite hook -> command:null, no throw");
    pass++;
  } else {
    console.log(`FAIL: unspawnable rewrite hook — threw=${threw} res=${JSON.stringify(res)}`);
    fail++;
  }
}

console.log("----");
console.log(`pass=${pass} fail=${fail}`);
process.exit(fail === 0 ? 0 : 1);
