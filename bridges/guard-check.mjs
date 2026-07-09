// Shared bridge: run guard-all.sh with the JSON envelope Claude Code sends and report
// a single block/allow decision. Used by the in-process JS plugins (opencode / kilocode /
// cline / pi) which can't consume an exit-code/stdout hook directly.
//
// guard-all emits Claude-style JSON on stdout (permissionDecision deny/ask/allow). These
// agents have no "ask" channel, so ask -> block here (Decision 5): safe, never fail-open.
//
// The canonical guard path is set at install time; override with TVS_GUARD_ALL.
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
// policy.mjs is placed beside this file by install.sh; in the repo it lives at core/policy.mjs.
import { isCommitCommand } from "./policy.mjs";

const GUARD =
  process.env.TVS_GUARD_ALL ||
  join(homedir(), ".config", "tvs-agent-shield", "guards", "guard-all.sh");

// push detection mirrors block-git-push.sh / guard-all.sh — used only to decide whether a
// guard-all spawn failure should fail closed (destructive) or allow (unrelated shell work).
const isPushCommand = (c) => typeof c === "string" && /\bgit\b[^|&;]*\bpush([\s]|$)/.test(c);
const isDangerous = (c) => isCommitCommand(c) || isPushCommand(c);

export function runGuardAll(command, cwd) {
  if (typeof command !== "string" || command.length === 0) {
    return Promise.resolve({ block: false });
  }
  const failClosed = isDangerous(command);
  const spawnFailReason = failClosed
    ? "TVS guard unavailable — refusing commit/push (fail-closed)."
    : null;

  return new Promise((resolve) => {
    let proc;
    try {
      proc = spawn(GUARD, [], { stdio: ["pipe", "pipe", "pipe"], timeout: 5000 });
    } catch {
      return resolve({ block: failClosed, reason: spawnFailReason });
    }
    let out = "";
    let err = "";
    proc.stdout.on("data", (d) => (out += d));
    proc.stderr.on("data", (d) => (err += d));
    proc.on("error", () => resolve({ block: failClosed, reason: spawnFailReason }));
    proc.on("close", (code) => {
      // Prefer the JSON decision; fall back to exit code if stdout is unusable.
      let decision = null;
      try {
        decision = JSON.parse(out)?.hookSpecificOutput?.permissionDecision ?? null;
      } catch {
        decision = null;
      }
      if (decision === "deny" || decision === "ask") {
        return resolve({ block: true, reason: err.trim() || `TVS guard: ${decision}.` });
      }
      if (decision === "allow") {
        return resolve({ block: false });
      }
      // Malformed / half-written stdout: honor exit 2, else fail closed only if dangerous.
      if (code === 2) return resolve({ block: true, reason: err.trim() || "TVS guard: blocked." });
      return resolve({ block: failClosed, reason: spawnFailReason });
    });
    proc.stdin.on("error", () => {});
    proc.stdin.end(JSON.stringify({ tool_input: { command }, cwd: cwd || process.cwd() }));
  });
}
