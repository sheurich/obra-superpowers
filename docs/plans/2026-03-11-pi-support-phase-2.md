# Pi Support Phase 2: Extension-Based Integration

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Pi extension that bootstraps `using-superpowers` on session start and maps Superpowers tool references to Pi equivalents, enable the `writing-plans → subagent-driven-development → requesting-code-review` workflow, ship integration tests, and add `package.json` for Pi package metadata.

**Architecture:** A TypeScript extension in `.pi/extensions/superpowers/` reads the `using-superpowers` skill content on `session_start` and appends it to the system prompt on every turn via `before_agent_start`, with a tool-mapping addendum. This approach survives compaction (the system prompt is never compacted) and matches the OpenCode system prompt transform pattern. The extension has no UI, no custom tools, and no external dependencies. Skills already work via Pi's native package discovery. The `code-reviewer` agent profile already exists from Phase 1. A `package.json` with `pi` metadata declares the extension path explicitly so `pi install` discovers it.

**Tech Stack:** TypeScript (Pi extension API), bash (tests)

**Tracking:** [obra/superpowers#435](https://github.com/obra/superpowers/issues/435)

---

## Open Design Decisions

1. **Extension complexity** — Phase 2 ships a minimal `session_start` bootstrap extension. Plan-mode and todo-tool extensions are Phase 3. This keeps the PR reviewable and avoids committing to API surfaces prematurely.

2. **`package.json` location** — Pi packages conventionally use a root `package.json` with a `pi` key. Superpowers has no `package.json` today. Adding one is the smallest change that enables explicit extension discovery. If the repo later adds npm-based tooling, this file already exists.

3. **Tool mapping approach** — The extension injects a text block mapping Claude Code tools to Pi equivalents. This is the same pattern the OpenCode plugin uses. No runtime tool shimming needed.

4. **Agent profile installation** — Phase 1 requires manual symlinks for `code-reviewer.md`. Phase 2 does not change this; auto-install is Phase 3 scope. The extension prints a one-time reminder if the profile is missing.

---

### Task 1: Add `package.json` with Pi package metadata

**Files:**
- Create: `package.json`

**Step 1: Create `package.json`**

```json
{
  "name": "superpowers",
  "version": "5.0.1",
  "description": "Core skills library: TDD, debugging, collaboration patterns, and proven techniques for coding agents",
  "keywords": ["pi-package"],
  "license": "MIT",
  "repository": "https://github.com/obra/superpowers",
  "pi": {
    "extensions": [".pi/extensions/superpowers"],
    "skills": ["skills"]
  }
}
```

The `pi.extensions` array tells Pi to load `.pi/extensions/superpowers/index.ts`. The `pi.skills` array is redundant with convention-based discovery but makes intent explicit.

**Step 2: Verify `pi install` still works with the new `package.json`**

Run the existing smoke test:

```bash
./tests/pi/run-tests.sh
```

Expected: PASS (the smoke test uses `pi install` from the repo root).

**Step 3: Commit**

```bash
git add package.json
git commit -m "feat(pi): add package.json with pi package metadata"
```

---

### Task 2: Create the bootstrap extension

**Files:**
- Create: `.pi/extensions/superpowers/index.ts`

**Step 1: Write the extension**

The extension:
1. On `session_start`, reads `skills/using-superpowers/SKILL.md` relative to the package root.
2. Strips YAML frontmatter.
3. Appends a Pi-specific tool mapping block.
4. Injects the combined content via `pi.sendMessage()` with `display: false` and `triggerTurn: false`.
5. Optionally checks if `code-reviewer.md` is installed and notifies if missing.

```typescript
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const extensionDir = path.dirname(fileURLToPath(import.meta.url));

function stripFrontmatter(content: string): string {
  const match = content.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
  return match ? match[1].trim() : content.trim();
}

export default function superpowersExtension(pi: ExtensionAPI): void {
  // .pi/extensions/superpowers/ → repo root (3 levels up)
  const packageRoot = path.resolve(extensionDir, "../../..");

  pi.on("session_start", async (_event, ctx) => {
    const skillPath = path.join(packageRoot, "skills", "using-superpowers", "SKILL.md");

    let skillContent: string;
    try {
      skillContent = fs.readFileSync(skillPath, "utf8");
    } catch {
      ctx.ui.notify("Superpowers: could not read using-superpowers skill", "error");
      return;
    }

    const body = stripFrontmatter(skillContent);

    const toolMapping = `**Tool Mapping for Pi:**
When skills reference tools you don't have, substitute Pi equivalents:
- \`TodoWrite\` → use markdown checklists in your response or the \`todo\` tool if available
- \`Task\` tool with subagents → \`subagent\` tool (single, parallel, or chain modes)
- \`Skill\` tool → \`read\` tool on the SKILL.md file, or \`/skill:name\` command
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → your native tools (same names)

**Skills location:**
Superpowers skills are installed as a Pi package.
Use \`read\` on a skill's SKILL.md to load it, or type \`/skill:name\`.`;

    const bootstrap = `<EXTREMELY_IMPORTANT>
You have superpowers.

**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED — you are currently following it. Do NOT use the read tool to load "using-superpowers" again.**

${body}

${toolMapping}
</EXTREMELY_IMPORTANT>`;

    pi.sendMessage(
      { customType: "superpowers-bootstrap", content: bootstrap, display: false },
      { triggerTurn: false },
    );

    // Check for code-reviewer agent profile
    const agentDir = process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");
    const reviewerPath = path.join(agentDir, "agents", "code-reviewer.md");
    if (!fs.existsSync(reviewerPath)) {
      ctx.ui.notify(
        "Superpowers: code-reviewer agent not installed. Some workflows need it.\n" +
        "See: .pi/agents/README.md for install instructions.",
        "info",
      );
    }
  });
}
```

**Step 2: Commit**

```bash
git add .pi/extensions/superpowers/index.ts
git commit -m "feat(pi): add bootstrap extension for session_start injection"
```

---

### Task 3: Add integration tests for the extension

**Files:**
- Create: `tests/pi/test-extension.sh`
- Modify: `tests/pi/run-tests.sh`

**Step 1: Write `tests/pi/test-extension.sh`**

The test verifies:
1. The extension file exists and has valid TypeScript syntax (parseable).
2. The extension can find `using-superpowers/SKILL.md` relative to its location.
3. `package.json` declares the extension path.
4. After `pi install`, the extension is discoverable.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

info "Pi extension integration test"

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

# Test 3: Extension references using-superpowers skill
SKILL_FILE="$REPO_ROOT/skills/using-superpowers/SKILL.md"
[ -f "$SKILL_FILE" ] || fail "using-superpowers SKILL.md not found"
grep -q "using-superpowers" "$EXT_FILE" || fail "extension does not reference using-superpowers"
pass "extension references using-superpowers skill"

# Test 4: Extension references tool mapping
grep -q "Tool Mapping" "$EXT_FILE" || fail "extension does not contain tool mapping"
pass "extension contains tool mapping"

# Test 5: Extension references code-reviewer check
grep -q "code-reviewer" "$EXT_FILE" || fail "extension does not check for code-reviewer"
pass "extension checks for code-reviewer agent"

# Test 6: Verify extension loads in isolated install (if pi available)
if command -v pi >/dev/null 2>&1; then
    TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/superpowers-pi-ext.XXXXXX")"
    cleanup() { rm -rf "$TMP_ROOT"; }
    trap cleanup EXIT

    export PI_CODING_AGENT_DIR="$TMP_ROOT/agent"
    mkdir -p "$PI_CODING_AGENT_DIR"

    if pi install "$REPO_ROOT" 2>&1; then
        pass "pi install succeeded with extension"

        # Check that package resolution includes the extension
        SETTINGS_FILE="$PI_CODING_AGENT_DIR/settings.json"
        if [ -f "$SETTINGS_FILE" ]; then
            pass "settings file created with extension package"
        else
            fail "settings file not found after install"
        fi
    else
        fail "pi install failed with extension"
    fi
else
    info "pi not found, skipping live install test"
fi

echo "All Pi extension integration tests passed."
```

**Step 2: Add the test to `run-tests.sh`**

In `tests/pi/run-tests.sh`, add `"test-extension.sh"` to the `tests` array:

```bash
tests=(
    "test-smoke.sh"
    "test-extension.sh"
)
```

**Step 3: Run the tests**

```bash
./tests/pi/run-tests.sh --verbose
```

Expected: Both tests PASS.

**Step 4: Commit**

```bash
git add tests/pi/test-extension.sh tests/pi/run-tests.sh
git commit -m "test(pi): add extension integration tests"
```

---

### Task 4: Add workflow test for planning → execution → review

**Files:**
- Create: `tests/pi/test-workflow.sh`
- Modify: `tests/pi/run-tests.sh`

**Step 1: Write `tests/pi/test-workflow.sh`**

This test verifies the structural prerequisites for the `writing-plans → subagent-driven-development → requesting-code-review` workflow on Pi:

1. The three skills exist and have valid SKILL.md frontmatter.
2. The `code-reviewer` agent profile exists in `.pi/agents/`.
3. The skill cross-references resolve (e.g., `subagent-driven-development` references `requesting-code-review`).
4. The `write-plan` and `execute-plan` commands exist.
5. Subagent prompt templates exist in `skills/subagent-driven-development/`.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

info() { echo "[INFO] $*"; }
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

info "Pi workflow integration test: planning → execution → review"

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

echo "All Pi workflow integration tests passed."
```

**Step 2: Add the test to `run-tests.sh`**

```bash
tests=(
    "test-smoke.sh"
    "test-extension.sh"
    "test-workflow.sh"
)
```

**Step 3: Run the tests**

```bash
./tests/pi/run-tests.sh --verbose
```

Expected: All tests PASS.

**Step 4: Commit**

```bash
git add tests/pi/test-workflow.sh tests/pi/run-tests.sh
git commit -m "test(pi): add workflow integration tests for planning→execution→review"
```

---

### Task 5: Update documentation

**Files:**
- Modify: `docs/README.pi.md`
- Modify: `.pi/INSTALL.md`
- Modify: `tests/pi/README.md`

**Step 1: Update `docs/README.pi.md`**

Add a "Bootstrap Extension" section after "Architecture" explaining:
- The extension injects `using-superpowers` on session start automatically
- No manual skill loading needed for bootstrap
- Tool mapping is injected automatically
- Code-reviewer check on startup

Update the "Known Differences from Claude Code" section:
- Remove "No hooks system" bullet — the extension now provides equivalent bootstrap
- Update the tool mapping note to say it's injected automatically

Update the "Architecture" section:
- Add that a Pi extension in `.pi/extensions/superpowers/` handles session bootstrap
- Note the `package.json` with `pi` metadata

**Step 2: Update `.pi/INSTALL.md`**

Add a note that `pi install` now also loads a bootstrap extension automatically.

**Step 3: Update `tests/pi/README.md`**

Add descriptions for `test-extension.sh` and `test-workflow.sh`.

**Step 4: Commit**

```bash
git add docs/README.pi.md .pi/INSTALL.md tests/pi/README.md
git commit -m "docs(pi): update docs for Phase 2 extension and workflow support"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | `package.json` with Pi metadata | `package.json` |
| 2 | Bootstrap extension | `.pi/extensions/superpowers/index.ts` |
| 3 | Extension integration tests | `tests/pi/test-extension.sh`, `tests/pi/run-tests.sh` |
| 4 | Workflow integration tests | `tests/pi/test-workflow.sh`, `tests/pi/run-tests.sh` |
| 5 | Documentation updates | `docs/README.pi.md`, `.pi/INSTALL.md`, `tests/pi/README.md` |

**What Phase 2 does NOT include (Phase 3):**
- Plan-mode extension (Pi has its own plan-mode example)
- Todo-tool extension (Pi has its own todo example)
- Auto-install of agent profiles
- `/write-plan` and `/execute-plan` as Pi commands (they exist as skill-triggered commands already)
- Broader workflow parity beyond the planning→execution→review path
