# Pi Test Suite

Run all tests from the repository root:

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

### `test-smoke.sh` — Isolated Install + Skill Discovery

Verifies:

1. `pi install` works with an isolated `HOME`
2. `PI_CODING_AGENT_DIR` is isolated under that temporary home
3. The install writes package settings into the isolated directory
4. Pi package resolution can discover `skills/brainstorming/SKILL.md` from this repo
5. Skill discovery does **not** leak in skills from the original home directory
6. `pi list` shows the installed local package
7. The real `~/.pi/agent/settings.json` is unchanged

### `test-extension.sh` — Bootstrap Extension Resolution + Loading

Verifies:

1. `package.json` declares `.pi/extensions/superpowers`
2. `pi install` succeeds in an isolated environment
3. Pi package resolution discovers the extension path from package metadata
4. Pi can actually load the extension module successfully
5. The extension registers `session_start` and `before_agent_start`
6. The injected prompt guidance changes honestly based on runtime tool availability:
   - no `subagent` tool → fallback to `executing-plans`
   - `subagent` tool present → map Task-style workflows to `subagent`
7. `TodoWrite` remains scoped to markdown-checklist fallback

### `test-compatibility.sh` — Phase 2 Compatibility Baseline Docs

Verifies:

1. `docs/README.pi.md` names the supported external subagent setup and minimum required agent profiles
2. `docs/README.pi.md` distinguishes plain Pi core from the supported subagent baseline
3. `.pi/INSTALL.md` matches the same narrow Phase 2 promise
4. `.pi/agents/README.md` makes clear that bundled agent profiles do not provide subagent support by themselves
5. `README.md` keeps the top-level Pi description scoped honestly
6. `.pi/agents/code-reviewer.md` still has valid frontmatter

## Requirements

- `pi` in `PATH`
- `node` in `PATH`
