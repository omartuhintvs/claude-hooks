// Kilo Code plugin — blocks commits to TVS org repos under a non-company email.
// Kilo mirrors opencode's plugin API but wraps the hooks in a { id, server } object.
// Install to ~/.config/kilo/plugin/ (global) or .kilo/plugin/ (project); identity-check.mjs
// sits alongside it. Docs: https://kilo.ai/docs/automate/extending/plugins
import { runIdentityGuard } from "./identity-check.mjs";

const server = async () => ({
  "tool.execute.before": async (input, output) => {
    if (input?.tool !== "bash") return;
    const command = output?.args?.command;
    const res = await runIdentityGuard(command, output?.args?.cwd);
    if (res.block) throw new Error(res.reason || "TVS identity guard: commit blocked.");
  },
});

export default { id: "tvs-identity-guard", server };
