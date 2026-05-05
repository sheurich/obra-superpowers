#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

README_PI="$REPO_ROOT/docs/README.pi.md"
INSTALL_DOC="$REPO_ROOT/.pi/INSTALL.md"
AGENTS_DOC="$REPO_ROOT/.pi/agents/README.md"
ROOT_README="$REPO_ROOT/README.md"

info "Pi compatibility baseline test"

for path in "$README_PI" "$INSTALL_DOC" "$AGENTS_DOC" "$ROOT_README"; do
    [ -f "$path" ] || fail "missing required file: $path"
done
pass "required Pi documentation files exist"

grep -q "Phase 2 Compatibility Baseline" "$README_PI" || fail "docs/README.pi.md does not describe the Phase 2 compatibility baseline"
grep -q 'examples/extensions/subagent' "$README_PI" || fail "docs/README.pi.md does not name the supported upstream subagent setup"
grep -q '`worker` agent' "$README_PI" || fail "docs/README.pi.md does not document the required worker agent"
grep -q 'builtin.*reviewer' "$README_PI" || fail "docs/README.pi.md does not document the builtin reviewer agent"
grep -q 'installed Pi agent profiles' "$README_PI" || fail "docs/README.pi.md does not say that the subagent path depends on the installed Pi agent profiles"
pass "docs/README.pi.md identifies the supported external subagent setup and minimum agent profiles"

grep -q 'plain Pi core' "$README_PI" || fail "docs/README.pi.md does not distinguish the plain Pi core baseline"
grep -q 'TodoWrite' "$README_PI" || fail "docs/README.pi.md does not document the TodoWrite fallback"
grep -q 'not part of the supported Phase 2 baseline' "$README_PI" || fail "docs/README.pi.md does not clearly exclude optional todo/plan-mode setup"
pass "docs/README.pi.md distinguishes supported behavior, fallbacks, and non-goals"

grep -q 'examples/extensions/subagent' "$INSTALL_DOC" || fail ".pi/INSTALL.md does not explain the supported subagent setup"
grep -q 'builtin.*reviewer' "$INSTALL_DOC" || fail ".pi/INSTALL.md does not mention builtin reviewer"
grep -q 'markdown checklists' "$INSTALL_DOC" || fail ".pi/INSTALL.md does not keep TodoWrite scoped to markdown fallback"
pass ".pi/INSTALL.md matches the documented Phase 2 promise"

grep -q 'builtin.*reviewer' "$AGENTS_DOC" || fail ".pi/agents/README.md does not explain builtin reviewer usage"
pass ".pi/agents/README.md documents review agent approach"

grep -q 'plain Pi core gives you the install/bootstrap/planning baseline' "$ROOT_README" || fail "README.md does not summarize the narrow Pi baseline honestly"
grep -q 'Todo/task-tracker and plan-mode integration are not part of the supported Phase 2 baseline' "$ROOT_README" || fail "README.md does not keep Phase 2 scoped"
pass "README.md summarizes the Pi scope honestly"

echo "All Pi compatibility baseline checks passed."
