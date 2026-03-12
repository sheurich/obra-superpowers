#!/usr/bin/env bash
# Test: Pi Extension Integration
# Verifies the bootstrap extension structure, package.json metadata,
# and that pi install discovers the extension in an isolated environment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

info "Pi extension integration test"

# Prerequisites
command -v node >/dev/null 2>&1 || fail "node is required but not found in PATH"

# Test 1: Extension file exists
EXT_FILE="$REPO_ROOT/.pi/extensions/superpowers/index.ts"
[ -f "$EXT_FILE" ] || fail "extension file not found: $EXT_FILE"
pass "extension file exists"

# Test 2: package.json declares extension path
[ -f "$REPO_ROOT/package.json" ] || fail "package.json not found"
node -e "
const pkg = require('$REPO_ROOT/package.json');
const exts = pkg.pi && pkg.pi.extensions;
if (!Array.isArray(exts) || !exts.some(e => e.includes('.pi/extensions/superpowers'))) {
  console.error('package.json pi.extensions does not include .pi/extensions/superpowers');
  process.exit(1);
}
console.log('pi.extensions:', JSON.stringify(exts));
" || fail "package.json does not declare extension"
pass "package.json declares extension path"

# Test 3: Extension has valid structure (exports default function, uses ExtensionAPI)
grep -q "export default function" "$EXT_FILE" || fail "extension does not export default function"
grep -q "ExtensionAPI" "$EXT_FILE" || fail "extension does not reference ExtensionAPI"
pass "extension has valid structure"

# Test 4: Extension references using-superpowers skill
SKILL_FILE="$REPO_ROOT/skills/using-superpowers/SKILL.md"
[ -f "$SKILL_FILE" ] || fail "using-superpowers SKILL.md not found"
grep -q "using-superpowers" "$EXT_FILE" || fail "extension does not reference using-superpowers"
pass "extension references using-superpowers skill"

# Test 5: Extension references tool mapping
grep -q "Tool Mapping" "$EXT_FILE" || fail "extension does not contain tool mapping"
pass "extension contains tool mapping"

# Test 6: Extension references code-reviewer check
grep -q "code-reviewer" "$EXT_FILE" || fail "extension does not check for code-reviewer"
pass "extension checks for code-reviewer agent"

# Test 7: Extension uses before_agent_start for compaction resilience
grep -q "before_agent_start" "$EXT_FILE" || fail "extension does not use before_agent_start"
pass "extension uses before_agent_start for system prompt injection"

# Test 8: Verify extension loads in isolated install (if pi available)
if command -v pi >/dev/null 2>&1; then
    TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-pi-ext.XXXXXX")"
    cleanup() { rm -rf "$TMP_ROOT"; }
    trap cleanup EXIT

    export PI_CODING_AGENT_DIR="$TMP_ROOT/agent"
    mkdir -p "$PI_CODING_AGENT_DIR"

    if INSTALL_OUTPUT="$(pi install "$REPO_ROOT" 2>&1)"; then
        echo "$INSTALL_OUTPUT"
        pass "pi install succeeded with extension"

        # Check that settings file was created
        SETTINGS_FILE="$PI_CODING_AGENT_DIR/settings.json"
        [ -f "$SETTINGS_FILE" ] || fail "settings file not found after install"
        pass "settings file created with extension package"
    else
        echo "$INSTALL_OUTPUT" >&2
        fail "pi install failed with extension"
    fi
else
    info "pi not found, skipping live install test"
fi

echo "All Pi extension integration tests passed."
