// opencode plugin — blocks commits to TVS org repos under a non-company email.
// opencode calls `tool.execute.before` in-process and blocks when the hook throws.
// Install to ~/.config/opencode/plugin/ (global) or .opencode/plugin/ (project);
// identity-check.mjs sits alongside it. Docs: https://opencode.ai/docs/plugins/
import { runIdentityGuard } from "./identity-check.mjs";

export default {
  "tool.execute.before": async (input, output) => {
    if (input?.tool !== "bash") return;
    const command = output?.args?.command;
    const res = await runIdentityGuard(command, output?.args?.cwd);
    if (res.block) throw new Error(res.reason || "TVS identity guard: commit blocked.");
  },
};
