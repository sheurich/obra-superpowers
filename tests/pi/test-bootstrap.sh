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

info "Pi bootstrap test: extension discovery + deterministic prompt injection"

require_command pi
require_command node

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-pi-bootstrap.XXXXXX")"
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
if BOOTSTRAP_OUTPUT="$(node --input-type=module <<'NODE'
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
const enabledExtensions = resolved.extensions
  .filter((extension) => extension.enabled)
  .map((extension) => path.resolve(extension.path));

const bootstrapPath = path.join(repoRoot, '.pi', 'extensions', 'bootstrap.ts');
if (!enabledExtensions.includes(bootstrapPath)) {
  console.error('bootstrap extension was not discoverable in resolved extensions');
  process.exit(1);
}

const requireFromPi = createRequire(pathToFileURL(path.join(piPackageRoot, 'package.json')).href);
const jitiFactory = requireFromPi('@mariozechner/jiti');
const jiti = jitiFactory(path.join(repoRoot, 'tests', 'pi', 'test-bootstrap.sh'));
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

if (!firstPass.systemPrompt.includes(marker)) {
  console.error('bootstrap marker missing from injected system prompt');
  process.exit(1);
}

if (!firstPass.systemPrompt.includes('Tool mapping for Pi')) {
  console.error('tool mapping section missing from injected system prompt');
  process.exit(1);
}

if (!firstPass.systemPrompt.includes('using-superpowers')) {
  console.error('using-superpowers content missing from injected system prompt');
  process.exit(1);
}

const secondPass = await beforeAgentStart({ systemPrompt: firstPass.systemPrompt }, {});
if (secondPass !== undefined) {
  console.error('bootstrap extension should not inject duplicate content');
  process.exit(1);
}

console.log(`Resolved extensions: ${enabledExtensions.length}`);
console.log(`Found: ${bootstrapPath}`);
NODE
)"; then
    echo "$BOOTSTRAP_OUTPUT"
    pass "Pi resolves bootstrap extension and injects deterministic prompt content"
else
    echo "$BOOTSTRAP_OUTPUT" >&2
    fail "bootstrap resolution/injection check failed"
fi

echo "All Pi bootstrap checks passed."
