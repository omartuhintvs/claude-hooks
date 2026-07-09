// Tests bridges/guard-check.mjs's runGuardAll against the live guard-all.sh chain.
// guard-check.mjs imports "./policy.mjs" (a sibling placed by install.sh); in the repo
// policy.mjs lives at core/policy.mjs, so we copy both files into a temp dir and
// dynamic-import from there.
import { mkdtempSync, copyFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(__dirname, "..");

const tmp = mkdtempSync(join(tmpdir(), "guard-plugin-test-"));
copyFileSync(join(REPO_ROOT, "bridges", "guard-check.mjs"), join(tmp, "guard-check.mjs"));
copyFileSync(join(REPO_ROOT, "core", "policy.mjs"), join(tmp, "policy.mjs"));

process.env.TVS_GUARD_ALL = join(REPO_ROOT, "guards", "guard-all.sh");
process.env.TVS_SHIELD_HOME = REPO_ROOT;
process.env.TVS_WRITE_GUARD = join(REPO_ROOT, "guards", "write-guard.py");
process.env.TVS_IDENTITY_GUARD = join(REPO_ROOT, "guards", "identity-guard.sh");
process.env.TVS_GIT_PUSH_HOOK = join(REPO_ROOT, "guards", "block-git-push.sh");

const { runGuardAll } = await import(pathToFileURL(join(tmp, "guard-check.mjs")).href);

let pass = 0;
let fail = 0;

async function expectBlock(desc, command, wantBlock) {
  const res = await runGuardAll(command, REPO_ROOT);
  if (res.block === wantBlock) {
    console.log(`PASS: ${desc}`);
    pass++;
  } else {
    console.log(`FAIL: ${desc} — got block=${res.block} want block=${wantBlock}`);
    fail++;
  }
}

const DKR = "do" + "cker rm -f x";
const SQL = "psql -c 'D" + "ROP TABLE t'";
const PSH = "git -C /x pu" + "sh o m";
const BADCOMMIT = "cd /tmp/technovativesolutions/r && git -c user.email=bad@gmail.com commit -m x";

await expectBlock("docker rm blocked", DKR, true);
await expectBlock("psql DROP blocked", SQL, true);
await expectBlock("bad-email commit blocked", BADCOMMIT, true);
await expectBlock("push blocked", PSH, true);
await expectBlock("git status allowed", "git status", false);
await expectBlock("echo hi allowed", "echo hi", false);

// guard-all unspawnable
process.env.TVS_GUARD_ALL = join(tmp, "does-not-exist.sh");
const tmp2 = mkdtempSync(join(tmpdir(), "guard-plugin-test2-"));
copyFileSync(join(REPO_ROOT, "bridges", "guard-check.mjs"), join(tmp2, "guard-check.mjs"));
copyFileSync(join(REPO_ROOT, "core", "policy.mjs"), join(tmp2, "policy.mjs"));
const { runGuardAll: runGuardAll2 } = await import(pathToFileURL(join(tmp2, "guard-check.mjs")).href);

{
  const res = await runGuardAll2(BADCOMMIT, REPO_ROOT);
  if (res.block === true) {
    console.log("PASS: guard-all unspawnable + commit -> block");
    pass++;
  } else {
    console.log(`FAIL: guard-all unspawnable + commit — got block=${res.block} want true`);
    fail++;
  }
}
{
  const res = await runGuardAll2("git status", REPO_ROOT);
  if (res.block === false) {
    console.log("PASS: guard-all unspawnable + git status -> allow");
    pass++;
  } else {
    console.log(`FAIL: guard-all unspawnable + git status — got block=${res.block} want false`);
    fail++;
  }
}

rmSync(tmp, { recursive: true, force: true });
rmSync(tmp2, { recursive: true, force: true });

console.log("----");
console.log(`pass=${pass} fail=${fail}`);
process.exit(fail === 0 ? 0 : 1);
