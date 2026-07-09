// pi (earendil-works/pi) extension — blocks commits to TVS org repos under a
// non-company email. pi fires `tool_call` in-process before a tool runs and blocks
// when the callback returns { block: true }. Install to ~/.pi/agent/extensions/;
// identity-check.mjs sits alongside. Docs:
// https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md
import { runIdentityGuard } from "./identity-check.mjs";

export default function (pi) {
  pi.on("tool_call", async (event) => {
    if (event?.toolName !== "bash") return;
    const res = await runIdentityGuard(event?.input?.command, process.cwd());
    if (res.block) return { block: true, reason: res.reason || "TVS identity guard: commit blocked." };
  });
}
