# Pi Test Suite

Run all tests from repository root:

```bash
./tests/pi/run-tests.sh
```

Run with verbose output:

```bash
./tests/pi/run-tests.sh --verbose
```

Run a specific test:

```bash
./tests/pi/run-tests.sh --test test-smoke.sh
```

## Tests

### `test-smoke.sh` — Install + Skill Discovery

Verifies:

1. `pi install` works with an isolated `PI_CODING_AGENT_DIR` (temp directory)
2. The install writes package settings into that isolated directory
3. Pi package resolution can discover `skills/brainstorming/SKILL.md` from this repo
4. `pi list` shows the installed local package
5. `~/.pi/agent/settings.json` is unchanged (guard against accidental global writes)

### `test-extension.sh` — Bootstrap Extension Integration

Verifies:

1. Extension file exists at `.pi/extensions/superpowers/index.ts`
2. `package.json` declares the extension path in `pi.extensions`
3. Extension has valid structure (exports default function, uses `ExtensionAPI`)
4. Extension references `using-superpowers` skill content
5. Extension contains tool mapping block
6. Extension checks for `code-reviewer` agent profile
7. Extension uses `before_agent_start` for compaction-resilient system prompt injection
8. `pi install` succeeds with the extension package (live test, if `pi` is available)

### `test-workflow.sh` — Workflow Integration (planning → execution → review)

Verifies structural prerequisites for the supported end-to-end workflow:

1. Required skills exist with valid frontmatter: `writing-plans`, `subagent-driven-development`, `requesting-code-review`
2. `code-reviewer` agent profile exists with valid frontmatter
3. Subagent prompt templates exist in `skills/subagent-driven-development/`
4. Commands exist: `write-plan`, `execute-plan`
5. Skill cross-references resolve correctly
6. Extension tool mapping covers the `subagent` tool

## Requirements

- `pi` in `PATH` (for live install tests; skipped if not available)
- `node` in `PATH`
