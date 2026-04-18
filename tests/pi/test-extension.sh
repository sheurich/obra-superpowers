#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }
require_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || fail "missing required command: $cmd"
}

info "Pi extension integration test"

require_command pi
require_command node

EXT_FILE="$REPO_ROOT/.pi/extensions/superpowers/index.ts"
[ -f "$EXT_FILE" ] || fail "extension file not found: $EXT_FILE"
pass "extension file exists"

[ -f "$REPO_ROOT/package.json" ] || fail "package.json not found"
node -e "
const pkg = require('$REPO_ROOT/package.json');
const exts = pkg.pi && pkg.pi.extensions;
if (!Array.isArray(exts) || !exts.includes('.pi/extensions/superpowers')) {
  console.error('package.json pi.extensions does not include .pi/extensions/superpowers');
  process.exit(1);
}
console.log('pi.extensions:', JSON.stringify(exts));
" || fail "package.json does not declare extension"
pass "package.json declares extension path"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-pi-ext.XXXXXX")"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

export HOME="$TMP_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
mkdir -p "$PI_CODING_AGENT_DIR" "$XDG_CONFIG_HOME"

PI_BIN="$(command -v pi)"
if ! PI_REALPATH="$(node -e 'const fs=require("fs");console.log(fs.realpathSync(process.argv[1]))' "$PI_BIN" 2>/dev/null)"; then
    fail "unable to resolve pi binary path"
fi
PI_PACKAGE_ROOT="$(cd "$(dirname "$PI_REALPATH")/.." && pwd)"

if INSTALL_OUTPUT="$(pi install "$REPO_ROOT" 2>&1)"; then
    echo "$INSTALL_OUTPUT"
    pass "pi install succeeded with isolated HOME"
else
    echo "$INSTALL_OUTPUT" >&2
    fail "pi install failed with extension"
fi

SETTINGS_FILE="$PI_CODING_AGENT_DIR/settings.json"
[ -f "$SETTINGS_FILE" ] || fail "settings file not found after install"
pass "settings file created"

export REPO_ROOT PI_PACKAGE_ROOT SETTINGS_FILE PI_CODING_AGENT_DIR
if EXTENSION_OUTPUT="$(node --input-type=module <<'NODE'
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const repoRoot = path.resolve(process.env.REPO_ROOT);
const settingsPath = process.env.SETTINGS_FILE;
const packageRoot = process.env.PI_PACKAGE_ROOT;
const agentDir = process.env.PI_CODING_AGENT_DIR;
const expectedExtensionPath = path.join(repoRoot, '.pi', 'extensions', 'superpowers', 'index.ts');

const { SettingsManager } = await import(
  pathToFileURL(path.join(packageRoot, 'dist/core/settings-manager.js')).href
);
const { DefaultPackageManager } = await import(
  pathToFileURL(path.join(packageRoot, 'dist/core/package-manager.js')).href
);
const { loadExtensions } = await import(
  pathToFileURL(path.join(packageRoot, 'dist/core/extensions/loader.js')).href
);

const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
if (!Array.isArray(settings.packages) || settings.packages.length === 0) {
  console.error('settings.json does not contain installed packages');
  process.exit(1);
}

const settingsManager = SettingsManager.create(repoRoot, agentDir);
const packageManager = new DefaultPackageManager({
  cwd: repoRoot,
  agentDir,
  settingsManager,
});
const resolved = await packageManager.resolve();
const extensionPaths = resolved.extensions.filter((entry) => entry.enabled).map((entry) => path.resolve(entry.path));

if (!extensionPaths.includes(expectedExtensionPath)) {
  console.error(`resolved extensions did not include ${expectedExtensionPath}`);
  process.exit(1);
}

const { extensions, errors, runtime } = await loadExtensions(extensionPaths, repoRoot);
if (errors.length > 0) {
  console.error(`extension loading failed: ${JSON.stringify(errors, null, 2)}`);
  process.exit(1);
}
if (extensions.length !== 1) {
  console.error(`expected exactly one loaded extension, got ${extensions.length}`);
  process.exit(1);
}

const extension = extensions[0];
const sessionHandlers = extension.handlers.get('session_start') ?? [];
const beforeHandlers = extension.handlers.get('before_agent_start') ?? [];
if (sessionHandlers.length === 0 || beforeHandlers.length === 0) {
  console.error('extension did not register session_start and before_agent_start handlers');
  process.exit(1);
}

const notifications = [];
const ctx = {
  ui: {
    notify(message, level) {
      notifications.push({ message, level });
    },
  },
};
const sessionStart = sessionHandlers[0];
const beforeAgentStart = beforeHandlers[0];

runtime.getActiveTools = () => ['read', 'write', 'edit', 'bash'];
await sessionStart({ reason: 'startup' }, ctx);
const noSubagentPrompt = await beforeAgentStart({
  prompt: 'test prompt',
  images: [],
  systemPrompt: 'BASE',
}, ctx);

if (!noSubagentPrompt?.systemPrompt?.includes('no direct equivalent in this session')) {
  console.error('fallback prompt did not explain that subagent support is unavailable');
  process.exit(1);
}
if (!noSubagentPrompt.systemPrompt.includes('superpowers:executing-plans')) {
  console.error('fallback prompt did not steer to executing-plans');
  process.exit(1);
}
if (!noSubagentPrompt.systemPrompt.includes('Do not assume a dedicated todo tool is available')) {
  console.error('TodoWrite fallback did not stay scoped to markdown checklists');
  process.exit(1);
}
if (!notifications.some((entry) => entry.message.includes('no active subagent tool detected'))) {
  console.error('session_start did not emit the expected no-subagent guidance');
  process.exit(1);
}

await fs.promises.mkdir(path.join(agentDir, 'agents'), { recursive: true });
await fs.promises.writeFile(path.join(agentDir, 'agents', 'code-reviewer.md'), 'placeholder\n', 'utf8');
notifications.length = 0;
runtime.getActiveTools = () => ['read', 'write', 'edit', 'bash', 'subagent'];
await sessionStart({ reason: 'reload' }, ctx);
const withSubagentPrompt = await beforeAgentStart({
  prompt: 'test prompt',
  images: [],
  systemPrompt: 'BASE',
}, ctx);

if (!withSubagentPrompt?.systemPrompt?.includes('`Task` tool with subagents → `subagent` tool')) {
  console.error('prompt did not map Task to subagent when the tool is available');
  process.exit(1);
}
if (!withSubagentPrompt.systemPrompt.includes('Use the documented subagent workflow path with the installed Pi agent profiles.')) {
  console.error('prompt did not use the hardened subagent guidance');
  process.exit(1);
}
if (withSubagentPrompt.systemPrompt.includes('isolated Task-style workflows are available')) {
  console.error('prompt still used the overly broad subagent wording');
  process.exit(1);
}
if (!withSubagentPrompt.systemPrompt.includes('bundled `code-reviewer` agent profile')) {
  console.error('prompt did not mention the code-reviewer profile when installed');
  process.exit(1);
}
if (withSubagentPrompt.systemPrompt.includes('no direct equivalent in this session')) {
  console.error('prompt still claimed subagent support was unavailable');
  process.exit(1);
}

console.log(`Resolved extension: ${expectedExtensionPath}`);
console.log('Loaded extension handlers: session_start, before_agent_start');
console.log('Verified prompt guidance for both plain Pi core and compatible subagent setup.');
NODE
)"; then
    echo "$EXTENSION_OUTPUT"
    pass "extension resolves from package metadata, loads, and adapts its prompt guidance to runtime tool availability"
else
    echo "$EXTENSION_OUTPUT" >&2
    fail "extension resolution/loading check failed"
fi

echo "All Pi extension integration checks passed."
