// Shared bridge: run rtk-rewrite.sh with the same JSON envelope Claude Code sends, and
// report the rewritten command (if any). Used by the in-process JS plugins (opencode /
// kilocode / cline / pi) which can't consume an exit-code/stdout hook directly.
//
// Rewriting is best-effort and NEVER blocks: rtk absent, spawn failure, malformed output,
// or no matching rewriter all resolve to { command: null } — never throw.
//
// The canonical rewrite hook path is set at install time; override with TVS_RTK_REWRITE.
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

const REWRITE =
  process.env.TVS_RTK_REWRITE ||
  join(homedir(), ".config", "tvs-agent-shield", "guards", "rtk-rewrite.sh");

export function runRewrite(command, cwd) {
  if (typeof command !== "string" || command.length === 0) {
    return Promise.resolve({ command: null });
  }
  return new Promise((resolve) => {
    let proc;
    try {
      proc = spawn(REWRITE, [], { stdio: ["pipe", "pipe", "pipe"], timeout: 5000 });
    } catch {
      return resolve({ command: null });
    }
    let out = "";
    proc.stdout.on("data", (d) => (out += d));
    proc.stderr.on("data", () => {});
    proc.on("error", () => resolve({ command: null }));
    proc.on("close", () => {
      try {
        const rewritten = JSON.parse(out)?.hookSpecificOutput?.updatedInput?.command ?? null;
        resolve({ command: typeof rewritten === "string" && rewritten.length > 0 ? rewritten : null });
      } catch {
        resolve({ command: null });
      }
    });
    proc.stdin.on("error", () => {});
    proc.stdin.end(JSON.stringify({ tool_input: { command }, cwd: cwd || process.cwd() }));
  });
}
