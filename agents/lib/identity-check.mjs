// Shared bridge: run identity-guard.sh with the same JSON envelope Claude Code sends,
// and report whether it blocked (exit code 2). Used by the opencode / kilocode / cline
// plugins, which are in-process JS callbacks and can't consume an exit-code hook directly.
//
// The canonical guard path is set at install time; override with TVS_IDENTITY_GUARD.
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const GUARD =
  process.env.TVS_IDENTITY_GUARD ||
  join(homedir(), ".config", "tvs-agent-shield", "identity-guard.sh");

// Only commit-CREATING git commands are worth checking here; identity-guard.sh guards
// commits, and `git push` is already covered universally by the git pre-push hook.
// Everything else is allowed fast so a missing guard never blocks unrelated shell work.
const COMMITISH =
  /\bgit\b[^|&;]*\b(commit|amend|cherry-pick|rebase|revert|merge|commit-tree|am)\b/;

export function runIdentityGuard(command, cwd) {
  if (typeof command !== "string" || !COMMITISH.test(command)) {
    return Promise.resolve({ block: false });
  }
  return new Promise((resolve) => {
    let proc;
    try {
      proc = spawn(GUARD, [], { stdio: ["pipe", "ignore", "pipe"], timeout: 5000 });
    } catch {
      // Guard can't be spawned but this IS a commit command → fail closed.
      return resolve({ block: true, reason: "TVS identity guard unavailable — refusing commit." });
    }
    let err = "";
    proc.stderr.on("data", (d) => (err += d));
    proc.on("error", () =>
      resolve({ block: true, reason: "TVS identity guard unavailable — refusing commit." })
    );
    // Guard exits 0 = allow, 2 = policy block, anything else = crash/timeout. For a
    // commit-ish command, treat every non-zero (incl. null from a killed timeout) as block.
    proc.on("close", (code) =>
      resolve({ block: code !== 0, reason: err.trim() || "TVS identity guard error — refusing commit." })
    );
    proc.stdin.on("error", () => {});
    proc.stdin.end(JSON.stringify({ tool_input: { command }, cwd: cwd || process.cwd() }));
  });
}
