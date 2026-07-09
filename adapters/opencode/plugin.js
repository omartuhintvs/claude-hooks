// opencode plugin — blocks commits to TVS org repos under a non-company email.
// opencode calls `tool.execute.before` in-process and blocks when the hook throws.
// Install to ~/.config/opencode/plugin/ (global) or .opencode/plugin/ (project);
// identity-check.mjs sits alongside it. Docs: https://opencode.ai/docs/plugins/
import { runGuardAll } from "./guard-check.mjs";
import { runRewrite } from "./rewrite-check.mjs";

export default {
  "tool.execute.before": async (input, output) => {
    if (input?.tool !== "bash") return;
    const command = output?.args?.command;
    const res = await runGuardAll(command, output?.args?.cwd);
    if (res.block) throw new Error(res.reason || "TVS guard: command blocked.");
    const { command: rewritten } = await runRewrite(command, output?.args?.cwd);
    if (rewritten) output.args.command = rewritten;
  },
};
