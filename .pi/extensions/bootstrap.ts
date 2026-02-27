import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const EXTENSION_DIR = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(EXTENSION_DIR, "../..");
const USING_SUPERPOWERS_SKILL = path.join(REPO_ROOT, "skills", "using-superpowers", "SKILL.md");

export const BOOTSTRAP_MARKER = "SUPERPOWERS_PI_BOOTSTRAP_V1";

export function stripFrontmatter(markdown: string): string {
	const match = markdown.match(/^---\r?\n[\s\S]*?\r?\n---\r?\n([\s\S]*)$/);
	if (!match) {
		return markdown;
	}
	return match[1];
}

export function loadUsingSuperpowersSkill(skillPath: string = USING_SUPERPOWERS_SKILL): string | null {
	if (!fs.existsSync(skillPath)) {
		return null;
	}

	const fullContent = fs.readFileSync(skillPath, "utf8");
	return stripFrontmatter(fullContent).trim();
}

export function buildBootstrapBlock(usingSuperpowersContent: string): string {
	return `<EXTREMELY_IMPORTANT>
${BOOTSTRAP_MARKER}
You have superpowers.

The using-superpowers skill content is included below and is already loaded. Do not load using-superpowers again.

${usingSuperpowersContent}

Tool mapping for Pi:
- Skill tool -> Use /skill:<name> or read the matching SKILL.md file directly.
- Task tool (subagents) -> Use subagent when available in this harness.
- TodoWrite -> Use markdown checklists in your response.
- Read/Write/Edit/Bash -> Use Pi tools with the same names.
</EXTREMELY_IMPORTANT>`;
}

export default function superpowersPiBootstrap(pi: ExtensionAPI): void {
	let cachedBootstrap: string | null | undefined;

	const getBootstrap = (): string | null => {
		if (cachedBootstrap !== undefined) {
			return cachedBootstrap;
		}

		const content = loadUsingSuperpowersSkill();
		cachedBootstrap = content ? buildBootstrapBlock(content) : null;
		return cachedBootstrap;
	};

	pi.on("before_agent_start", async (event) => {
		const bootstrap = getBootstrap();
		if (!bootstrap) {
			return;
		}

		if (event.systemPrompt.includes(BOOTSTRAP_MARKER)) {
			return;
		}

		return {
			systemPrompt: `${event.systemPrompt}\n\n${bootstrap}`,
		};
	});
}
