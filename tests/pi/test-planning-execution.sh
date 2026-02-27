#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info() {
    echo "[INFO] $*"
}

pass() {
    echo "[PASS] $*"
}

fail() {
    echo "[FAIL] $*" >&2
    exit 1
}

require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd"
}

info "Pi planning/execution integration test: package + bootstrap + workflow resources"

require_command pi
require_command node

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-pi-e2e.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export PI_CODING_AGENT_DIR="$TMP_ROOT/agent"
mkdir -p "$PI_CODING_AGENT_DIR"

info "Using isolated PI_CODING_AGENT_DIR: $PI_CODING_AGENT_DIR"
info "Installing package from: $REPO_ROOT"

if INSTALL_OUTPUT="$(pi install "$REPO_ROOT" 2>&1)"; then
    echo "$INSTALL_OUTPUT"
    pass "pi install succeeded in isolated agent dir"
else
    echo "$INSTALL_OUTPUT" >&2
    fail "pi install failed"
fi

SETTINGS_FILE="$PI_CODING_AGENT_DIR/settings.json"
[ -f "$SETTINGS_FILE" ] || fail "expected settings file not found: $SETTINGS_FILE"

PI_BIN="$(command -v pi)"

export REPO_ROOT SETTINGS_FILE PI_CODING_AGENT_DIR PI_BIN
if E2E_OUTPUT="$(node --input-type=module <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

const repoRoot = path.resolve(process.env.REPO_ROOT);
const settingsPath = process.env.SETTINGS_FILE;
const agentDir = process.env.PI_CODING_AGENT_DIR;
const piBin = process.env.PI_BIN ?? 'pi';

const piRealPath = fs.realpathSync(piBin);
const piPackageRoot = path.resolve(path.dirname(piRealPath), '..');

const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
const packages = Array.isArray(settings.packages) ? settings.packages : [];
const sources = packages
  .map((entry) => (typeof entry === 'string' ? entry : entry?.source))
  .filter(Boolean);

const hasRepoSource = sources.some((source) => path.resolve(agentDir, source) === repoRoot);
if (!hasRepoSource) {
  console.error(`settings.json does not contain repository source for ${repoRoot}`);
  process.exit(1);
}

const { SettingsManager } = await import(
  pathToFileURL(path.join(piPackageRoot, 'dist/core/settings-manager.js')).href
);
const { DefaultPackageManager } = await import(
  pathToFileURL(path.join(piPackageRoot, 'dist/core/package-manager.js')).href
);

const settingsManager = SettingsManager.create(repoRoot, agentDir);
const packageManager = new DefaultPackageManager({
  cwd: repoRoot,
  agentDir,
  settingsManager,
});

const resolved = await packageManager.resolve();
const enabledSkillPaths = new Set(
  resolved.skills.filter((skill) => skill.enabled).map((skill) => path.resolve(skill.path)),
);

const workflowSkills = [
  path.join(repoRoot, 'skills', 'using-superpowers', 'SKILL.md'),
  path.join(repoRoot, 'skills', 'brainstorming', 'SKILL.md'),
  path.join(repoRoot, 'skills', 'writing-plans', 'SKILL.md'),
  path.join(repoRoot, 'skills', 'subagent-driven-development', 'SKILL.md'),
];

const missingSkills = workflowSkills.filter((skillPath) => !enabledSkillPaths.has(skillPath));
if (missingSkills.length > 0) {
  console.error(`missing planning/execution skills: ${missingSkills.join(', ')}`);
  process.exit(1);
}

const requireFromPi = createRequire(pathToFileURL(path.join(piPackageRoot, 'package.json')).href);
const jitiFactory = requireFromPi('@mariozechner/jiti');
const jiti = jitiFactory(path.join(repoRoot, 'tests', 'pi', 'test-planning-execution.sh'));
const bootstrapPath = path.join(repoRoot, '.pi', 'extensions', 'bootstrap.ts');
const bootstrapModule = await jiti.import(bootstrapPath);
const bootstrapExtension = bootstrapModule.default;
const marker = bootstrapModule.BOOTSTRAP_MARKER ?? 'SUPERPOWERS_PI_BOOTSTRAP_V1';

if (typeof bootstrapExtension !== 'function') {
  console.error('bootstrap extension does not export a default function');
  process.exit(1);
}

const handlers = new Map();
bootstrapExtension({
  on(eventName, handler) {
    handlers.set(eventName, handler);
  },
});

const beforeAgentStart = handlers.get('before_agent_start');
if (typeof beforeAgentStart !== 'function') {
  console.error('bootstrap extension did not register before_agent_start handler');
  process.exit(1);
}

const initialPrompt = 'BASE SYSTEM PROMPT';
const firstPass = await beforeAgentStart({ systemPrompt: initialPrompt }, {});
if (!firstPass?.systemPrompt) {
  console.error('bootstrap extension did not return modified system prompt');
  process.exit(1);
}

const requiredPromptSnippets = [
  marker,
  'using-superpowers',
  'Tool mapping for Pi',
  'Task tool (subagents) -> Use subagent when available in this harness.',
  'TodoWrite -> Use markdown checklists in your response.',
];

for (const snippet of requiredPromptSnippets) {
  if (!firstPass.systemPrompt.includes(snippet)) {
    console.error(`missing prompt snippet: ${snippet}`);
    process.exit(1);
  }
}

const secondPass = await beforeAgentStart({ systemPrompt: firstPass.systemPrompt }, {});
if (secondPass !== undefined) {
  console.error('bootstrap extension should not inject duplicate content');
  process.exit(1);
}

const requiredProfiles = [
  'implementer',
  'spec-reviewer',
  'code-quality-reviewer',
  'code-reviewer',
];
for (const profile of requiredProfiles) {
  const profilePath = path.join(repoRoot, '.pi', 'agents', `${profile}.md`);
  if (!fs.existsSync(profilePath)) {
    console.error(`missing profile: ${profilePath}`);
    process.exit(1);
  }
}

console.log(`Resolved skills: ${enabledSkillPaths.size}`);
console.log(`Validated workflow skills: ${workflowSkills.length}`);
console.log(`Validated profiles: ${requiredProfiles.length}`);
NODE
)"; then
    echo "$E2E_OUTPUT"
    pass "Pi planning/execution workflow resources resolve with bootstrap mapping"
else
    echo "$E2E_OUTPUT" >&2
    fail "planning/execution integration check failed"
fi

echo "All Pi planning/execution integration checks passed."
