/**
 * Superpowers bootstrap extension for Pi.
 *
 * Injects the using-superpowers skill content into the system prompt on every
 * turn, plus Pi-specific compatibility guidance that reflects the tools
 * actually available in the current session.
 *
 * Phase 2 scope is intentionally narrow:
 * - plain Pi core gets bootstrap + planning-friendly guidance
 * - Task/subagent workflows are only mapped when a compatible `subagent` tool
 *   is actually available
 * - TodoWrite falls back to markdown checklists
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

function getAgentDir(): string {
	return process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");
}

function hasInstalledAgent(agentName: string): boolean {
	return fs.existsSync(path.join(getAgentDir(), "agents", `${agentName}.md`));
}

function getActiveToolNames(pi: ExtensionAPI): string[] {
	try {
		const activeTools = pi.getActiveTools();
		if (!Array.isArray(activeTools)) return [];
		return activeTools
			.map((tool) => (typeof tool === "string" ? tool : tool && typeof tool === "object" ? tool.name : undefined))
			.filter((toolName): toolName is string => typeof toolName === "string");
	} catch {
		return [];
	}
}

function hasSubagentTool(pi: ExtensionAPI): boolean {
	return getActiveToolNames(pi).includes("subagent");
}

function buildToolMapping(options: { hasSubagent: boolean; hasCodeReviewer: boolean }): string {
	const lines = [
		"**Tool Mapping for Pi:**",
		"When skills reference tools you don't have, substitute Pi equivalents that actually exist in this session:",
		"- `TodoWrite` → use markdown checklists in your response or in a markdown file. Do not assume a dedicated todo tool is available.",
	];

	if (options.hasSubagent) {
		lines.push("- `Task` tool with subagents → `subagent` tool (single, parallel, or chain modes)");
		lines.push("");
		lines.push("**Subagent guidance for this session:**");
		lines.push("- A compatible `subagent` tool is active in this session. Use the documented subagent workflow path with the installed Pi agent profiles.");
		lines.push(
			"- For general isolated implementation work, use the general-purpose agent/profile from the installed subagent setup. The documented Phase 2 baseline uses Pi's upstream example `worker` agent.",
		);
		if (options.hasCodeReviewer) {
			lines.push(
				"- For `superpowers:requesting-code-review`, prefer the bundled `code-reviewer` agent profile when dispatching review work.",
			);
		} else {
			lines.push(
				"- `code-reviewer` is not installed in the Pi agents directory, so do not assume the dedicated review profile exists. Ask the user to install `.pi/agents/code-reviewer.md` or fall back to in-session review.",
			);
		}
	} else {
		lines.push("- `Task` tool with subagents → no direct equivalent in this session. No active `subagent` tool was detected.");
		lines.push("");
		lines.push("**Fallback behavior for this session:**");
		lines.push("- Treat this Pi session as a no-subagent harness.");
		lines.push("- Prefer `superpowers:executing-plans` over `superpowers:subagent-driven-development`.");
		lines.push("- Keep implementation review in the main session unless the user installs compatible external subagent support.");
	}

	lines.push("- `Skill` tool → `read` the relevant `SKILL.md`, or use `/skill:name`");
	lines.push("- `Read`, `Write`, `Edit`, `Bash` → your native tools (same names)");
	lines.push("");
	lines.push("**Phase 2 Pi scope reminders:**");
	lines.push("- Plain Pi core does not provide full Superpowers parity.");
	lines.push("- Pi's example `todo` and `plan-mode` extensions are not part of the supported Phase 2 baseline.");
	lines.push("");
	lines.push("**Skills location:**");
	lines.push("Superpowers skills are installed as a Pi package.");
	lines.push("Use `read` on a skill's `SKILL.md` to load it, or type `/skill:name`.");

	return lines.join("\n");
}

function buildBootstrap(skillBody: string, options: { hasSubagent: boolean; hasCodeReviewer: boolean }): string {
	return `<EXTREMELY_IMPORTANT>
You have superpowers.

**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED — you are currently following it. Do NOT use the read tool to load "using-superpowers" again.**

${skillBody}

${buildToolMapping(options)}
</EXTREMELY_IMPORTANT>`;
}

export default function superpowersExtension(pi: ExtensionAPI): void {
	// .pi/extensions/superpowers/ → repo root (3 levels up)
	const packageRoot = path.resolve(extensionDir, "../../..");
	let skillBody: string | null = null;
	let loadError = false;

	pi.on("session_start", async (_event, ctx) => {
		const skillPath = path.join(packageRoot, "skills", "using-superpowers", "SKILL.md");

		try {
			const raw = fs.readFileSync(skillPath, "utf8");
			skillBody = stripFrontmatter(raw);
			loadError = false;
		} catch {
			loadError = true;
			skillBody = null;
			ctx.ui.notify("Superpowers: could not read using-superpowers skill", "error");
			return;
		}

		const subagentAvailable = hasSubagentTool(pi);
		const codeReviewerInstalled = hasInstalledAgent("code-reviewer");

		if (!subagentAvailable) {
			ctx.ui.notify(
				"Superpowers: no active subagent tool detected. Plain Pi bootstrap/planning mode is active; Task-based workflows fall back to executing-plans. See docs/README.pi.md for the supported Phase 2 setup.",
				"info",
			);
			return;
		}

		if (!codeReviewerInstalled) {
			ctx.ui.notify(
				"Superpowers: subagent tool detected, but code-reviewer is not installed. The documented review path needs ~/.pi/agent/agents/code-reviewer.md. See .pi/agents/README.md for install instructions.",
				"info",
			);
		}
	});

	pi.on("before_agent_start", async (event) => {
		if (loadError || !skillBody) return;

		return {
			systemPrompt:
				event.systemPrompt +
				"\n\n" +
				buildBootstrap(skillBody, {
					hasSubagent: hasSubagentTool(pi),
					hasCodeReviewer: hasInstalledAgent("code-reviewer"),
				}),
		};
	});
}
