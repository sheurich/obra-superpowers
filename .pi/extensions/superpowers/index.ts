/**
 * Superpowers bootstrap extension for Pi
 *
 * Injects the using-superpowers skill content and Pi-specific tool mapping
 * into every agent turn via the system prompt, matching the behavior of the
 * Claude Code SessionStart hook and the OpenCode system prompt transform plugin.
 *
 * Uses before_agent_start to append to the system prompt on each turn.
 * This survives compaction (system prompt is never compacted) and avoids
 * piling up duplicate messages in the session.
 *
 * This extension has no custom tools, no UI, and no external dependencies.
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const extensionDir = path.dirname(fileURLToPath(import.meta.url));

function stripFrontmatter(content: string): string {
	const match = content.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n([\s\S]*)$/);
	return match ? match[1].trim() : content.trim();
}

export default function superpowersExtension(pi: ExtensionAPI): void {
	// .pi/extensions/superpowers/ → repo root (3 levels up)
	const packageRoot = path.resolve(extensionDir, "../../..");
	let bootstrapContent: string | null = null;
	let loadError = false;

	// Read skill content once on session start; notify if missing
	pi.on("session_start", async (_event, ctx) => {
		const skillPath = path.join(packageRoot, "skills", "using-superpowers", "SKILL.md");

		try {
			const raw = fs.readFileSync(skillPath, "utf8");
			const body = stripFrontmatter(raw);

			const toolMapping = `**Tool Mapping for Pi:**
When skills reference tools you don't have, substitute Pi equivalents:
- \`TodoWrite\` → use markdown checklists in your response or the \`todo\` tool if available
- \`Task\` tool with subagents → \`subagent\` tool (single, parallel, or chain modes)
- \`Skill\` tool → \`read\` tool on the SKILL.md file, or \`/skill:name\` command
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → your native tools (same names)

**Skills location:**
Superpowers skills are installed as a Pi package.
Use \`read\` on a skill's SKILL.md to load it, or type \`/skill:name\`.`;

			bootstrapContent = `<EXTREMELY_IMPORTANT>
You have superpowers.

**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED — you are currently following it. Do NOT use the read tool to load "using-superpowers" again.**

${body}

${toolMapping}
</EXTREMELY_IMPORTANT>`;
		} catch {
			loadError = true;
			ctx.ui.notify("Superpowers: could not read using-superpowers skill", "error");
		}

		// Check for code-reviewer agent profile
		const agentDir = process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");
		const reviewerPath = path.join(agentDir, "agents", "code-reviewer.md");
		if (!fs.existsSync(reviewerPath)) {
			ctx.ui.notify(
				"Superpowers: code-reviewer agent not installed. Some workflows need it.\n" +
					"See .pi/agents/README.md in the superpowers package for install instructions.",
				"info",
			);
		}
	});

	// Append bootstrap to system prompt on every turn — survives compaction
	pi.on("before_agent_start", async (event) => {
		if (loadError || !bootstrapContent) return;

		return {
			systemPrompt: event.systemPrompt + "\n\n" + bootstrapContent,
		};
	});
}
