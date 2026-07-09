// pi (earendil-works/pi) extension — blocks commits to TVS org repos under a
// non-company email. pi fires `tool_call` in-process before a tool runs and blocks
// when the callback returns { block: true }. Install to ~/.pi/agent/extensions/;
// identity-check.mjs sits alongside. Docs:
// https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md
import { runGuardAll } from "./guard-check.mjs";
import { runRewrite } from "./rewrite-check.mjs";

export default function (pi) {
  pi.on("tool_call", async (event) => {
    if (event?.toolName !== "bash") return;
    const res = await runGuardAll(event?.input?.command, process.cwd());
    if (res.block) return { block: true, reason: res.reason || "TVS guard: command blocked." };
    // ponytail: pi's tool_call event exposes no confirmed in-process way to mutate the
    // outgoing command (only a block return is documented), so rewriting is a no-op here —
    // blocks still apply via runGuardAll above.
    void runRewrite;
  });
}
