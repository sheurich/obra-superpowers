# Pi tests

Run from repository root:

```bash
./tests/pi/run-tests.sh
```

Run a specific test directly:

```bash
./tests/pi/test-smoke.sh
./tests/pi/test-bootstrap.sh
./tests/pi/test-planning-execution.sh
```

## test-smoke.sh

Verifies:

1. `pi install` works with an isolated `PI_CODING_AGENT_DIR` (temp directory)
2. Install writes package settings into that isolated directory
3. Pi package resolution discovers `skills/brainstorming/SKILL.md`
4. `pi list` shows the installed local package
5. `~/.pi/agent/settings.json` is unchanged (no accidental global writes)

## test-bootstrap.sh

Verifies:

1. Pi package resolution discovers `.pi/extensions/bootstrap.ts`
2. Bootstrap extension registers `before_agent_start`
3. Bootstrap injects deterministic `using-superpowers` + Pi tool mapping content
4. Bootstrap does not inject duplicate content if marker is already present

## test-planning-execution.sh

Verifies one end-to-end planning/execution integration path in Pi by checking:

1. Package install in isolated `PI_CODING_AGENT_DIR`
2. Planning/execution workflow skills resolve (`using-superpowers`, `brainstorming`, `writing-plans`, `subagent-driven-development`)
3. Bootstrap injects delegated-execution and task-tracking mapping text (`Task` -> `subagent`, `TodoWrite` -> markdown checklist)
4. Bundled Pi subagent profiles exist (`implementer`, `spec-reviewer`, `code-quality-reviewer`, `code-reviewer`)
5. Bootstrap remains deterministic (no duplicate injection)

Requirements:

- `pi` in `PATH`
- `node` in `PATH`
