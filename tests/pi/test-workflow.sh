#!/usr/bin/env bash
# Test: Pi Workflow Integration
# Verifies structural prerequisites for the
# writing-plans → subagent-driven-development → requesting-code-review
# workflow on Pi.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

info "Pi workflow integration test: planning → execution → review"

# Prerequisites
command -v node >/dev/null 2>&1 || fail "node is required but not found in PATH"

# Test 1: Required skills exist with valid frontmatter
for skill in writing-plans subagent-driven-development requesting-code-review; do
    skill_file="$REPO_ROOT/skills/$skill/SKILL.md"
    [ -f "$skill_file" ] || fail "skill not found: $skill"
    # Check frontmatter has name and description
    node -e "
const fs = require('fs');
const content = fs.readFileSync('$skill_file', 'utf8');
const match = content.match(/^---\\n([\\s\\S]*?)\\n---/);
if (!match) { console.error('no frontmatter'); process.exit(1); }
const fm = match[1];
if (!fm.includes('name:')) { console.error('no name in frontmatter'); process.exit(1); }
if (!fm.includes('description:')) { console.error('no description in frontmatter'); process.exit(1); }
" || fail "invalid frontmatter in $skill"
    pass "skill exists with valid frontmatter: $skill"
done

# Test 2: Code-reviewer agent profile exists
REVIEWER="$REPO_ROOT/.pi/agents/code-reviewer.md"
[ -f "$REVIEWER" ] || fail "code-reviewer agent profile not found at $REVIEWER"
# Verify it has the required frontmatter fields for Pi agents
grep -q "^name:" "$REVIEWER" || fail "code-reviewer missing name in frontmatter"
grep -q "^description:" "$REVIEWER" || fail "code-reviewer missing description in frontmatter"
pass "code-reviewer agent profile exists with valid frontmatter"

# Test 3: Subagent prompt templates exist
for template in implementer-prompt.md spec-reviewer-prompt.md code-quality-reviewer-prompt.md; do
    template_file="$REPO_ROOT/skills/subagent-driven-development/$template"
    [ -f "$template_file" ] || fail "prompt template not found: $template"
    pass "prompt template exists: $template"
done

# Test 4: Commands exist
for cmd in write-plan execute-plan; do
    cmd_file="$REPO_ROOT/commands/$cmd.md"
    [ -f "$cmd_file" ] || fail "command not found: $cmd"
    pass "command exists: $cmd"
done

# Test 5: Cross-references resolve
# subagent-driven-development should reference requesting-code-review
grep -q "requesting-code-review" "$REPO_ROOT/skills/subagent-driven-development/SKILL.md" || \
    fail "subagent-driven-development does not reference requesting-code-review"
pass "skill cross-references resolve"

# Test 6: Code-reviewer agent used by requesting-code-review
grep -q "code-reviewer" "$REPO_ROOT/skills/requesting-code-review/SKILL.md" || \
    fail "requesting-code-review does not reference code-reviewer"
pass "requesting-code-review references code-reviewer agent"

# Test 7: Bootstrap extension includes tool mapping for subagent
EXT_FILE="$REPO_ROOT/.pi/extensions/superpowers/index.ts"
grep -q "subagent" "$EXT_FILE" || fail "extension tool mapping does not mention subagent"
pass "extension tool mapping covers subagent tool"

echo "All Pi workflow integration tests passed."
