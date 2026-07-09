// Cline CLI/SDK plugin — blocks commits to TVS org repos under a non-company email.
//
// NOTE: the Cline VSCode extension has NO scriptable pre-exec hook — there the global
// git hook (git-hooks/_dispatch) is the only interception point. This plugin targets the
// Cline CLI/SDK `beforeTool` hook. The exact `context` shape for shell commands is not
// documented, so this reads the command defensively from several likely fields; the git
// hook remains the guaranteed backstop. Install to ~/.cline/plugins/ (global) or
// .cline/plugins/ (project). Docs: https://docs.cline.bot/sdk/plugin-examples.md
import { runGuardAll } from "./guard-check.mjs";
import { runRewrite } from "./rewrite-check.mjs";

function extractCommand(context) {
  return (
    context?.input?.command ??
    context?.args?.command ??
    context?.command ??
    context?.toolInput?.command ??
    null
  );
}

export default {
  id: "tvs-identity-guard",
  beforeTool: async (context) => {
    const command = extractCommand(context);
    const res = await runGuardAll(command, context?.cwd);
    if (res.block) {
      return { skip: true, reason: res.reason || "TVS guard: command blocked." };
    }
    // ponytail: Cline's beforeTool hook return contract (documented: { skip, reason }) has
    // no confirmed field for mutating the outgoing command, so rewriting is a no-op here —
    // blocks still apply via runGuardAll above.
    void runRewrite;
  },
};
