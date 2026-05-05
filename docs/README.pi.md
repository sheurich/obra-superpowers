# Superpowers for Pi

> **Experimental.** Pi support is new, and Phase 2 is intentionally scoped to one honest compatibility baseline rather than full harness parity.

Complete guide for using Superpowers with [pi](https://github.com/mariozechner/pi-coding-agent).

## Quick Install

```bash
pi install https://github.com/obra/superpowers
```

This installs Superpowers as a Pi package and loads a small bootstrap extension automatically.

That install alone gives you the **plain Pi core baseline**:
- skill discovery from the package
- automatic `using-superpowers` bootstrap injection
- Pi-specific tool guidance on each turn
- planning and other non-subagent workflows

If you want isolated Task-style execution/review on Pi, continue with the supported external setup below.

## Phase 2 Compatibility Baseline

| Setup | What Phase 2 supports | What it does **not** claim |
|---|---|---|
| **Plain Pi core + Superpowers** | Package install, bootstrap injection, skill discovery, planning, `executing-plans`, and other non-subagent skills | No built-in subagents, no `TodoWrite` equivalent, no full Superpowers parity |
| **Plain Pi core + Superpowers + Pi upstream `subagent` example extension + required agent profiles** | The documented isolated execution/review path for Phase 2 | Still no supported todo integration, no supported `plan-mode`, no broader parity claim |
| **Pi example `todo` / `plan-mode` extensions** | Optional experiments only | Not part of the supported Phase 2 baseline |

## What Plain Pi Core Supports

With only `pi install https://github.com/obra/superpowers`:

- Pi discovers skills from the package
- the Superpowers bootstrap extension injects `using-superpowers` automatically
- the extension detects that no `subagent` tool is available and steers Task-based workflows to fallback behavior
- planning works normally on Pi
- execution should use `superpowers:executing-plans` unless you install a compatible external `subagent` setup

## Supported External Setup for Isolated Subagent Workflows

The one supported Phase 2 subagent baseline is:

1. **Superpowers installed as a Pi package**
2. **Pi's upstream `examples/extensions/subagent` extension installed locally**
3. **A general-purpose worker agent from that setup** — the documented baseline uses the upstream `worker` agent
4. **The builtin `reviewer` agent from pi-subagents** — handles review dispatch via `subagents.agentOverrides` (no custom agent install needed)

This repo does **not** ship the `subagent` tool itself.

### Install Pi's upstream `subagent` example

Resolve the path to your local Pi installation, then symlink the example extension:

```bash
PI_INSTALL_DIR="$(node -p 'require("node:path").dirname(require.resolve("@mariozechner/pi-coding-agent/package.json"))')"
SUBAGENT_DIR="$PI_INSTALL_DIR/examples/extensions/subagent"

mkdir -p ~/.pi/agent/extensions/subagent
ln -sf "$SUBAGENT_DIR/index.ts" ~/.pi/agent/extensions/subagent/index.ts
ln -sf "$SUBAGENT_DIR/agents.ts" ~/.pi/agent/extensions/subagent/agents.ts
```

Install the minimum agent profile from that setup used by the documented baseline:

```bash
mkdir -p ~/.pi/agent/agents
ln -sf "$SUBAGENT_DIR/agents/worker.md" ~/.pi/agent/agents/worker.md
```

> If your Pi installation does not expose `examples/extensions/subagent` at that path, use the equivalent files from a local Pi source checkout. The supported baseline is the upstream example extension and its `worker` agent, not an arbitrary third-party subagent package.

### Review dispatch

Review dispatch uses the builtin `reviewer` agent from pi-subagents. No custom
agent install is needed. The superpowers extension translates
`superpowers:code-reviewer` references in skills to the builtin `reviewer`
automatically.

### Reload or restart Pi

Start a fresh Pi session after installing the external setup, or run `/reload` in an existing session.

## Verify Installation

### Superpowers package

```bash
pi list
```

You should see the Superpowers package in the installed package list.

### Required files for the supported subagent baseline

```bash
ls ~/.pi/agent/extensions/subagent/index.ts
ls ~/.pi/agent/agents/worker.md
```

If those files exist, the documented Phase 2 compatibility path is installed.

## Tool Mapping on Pi

The bootstrap extension injects the correct guidance automatically on every turn.

| Claude Code concept | Plain Pi core | Pi + supported subagent setup |
|---|---|---|
| `Skill` tool | `read` the skill's `SKILL.md`, or use `/skill:name` | Same |
| `TodoWrite` | Markdown checklists | Markdown checklists |
| `Task` with subagents | No direct equivalent; use `superpowers:executing-plans` | `subagent` tool with the installed Pi agent profiles from the supported setup |
| `Read` / `Write` / `Edit` / `Bash` | Same names | Same names |

When the supported subagent setup is present, use the documented subagent workflow path with the installed Pi agent profiles. Do not treat `subagent` alone as a broader parity guarantee.

## Supported Phase 2 Path

The supported Phase 2 path is intentionally narrow:

1. Install Superpowers on Pi
2. Use planning on Pi
3. If the supported external `subagent` setup is installed, use isolated subagent-based execution/review on Pi
4. Otherwise, use `superpowers:executing-plans` instead of claiming Task-style parity

## Architecture

Phase 2 uses Pi's native package and extension model:

1. `package.json` declares Pi package metadata
2. `.pi/extensions/superpowers/index.ts` reads `skills/using-superpowers/SKILL.md`
3. On `before_agent_start`, it appends the bootstrap content to the system prompt
4. The extension checks whether `subagent` is actually active and injects the matching guidance
5. `TodoWrite` stays a markdown-checklist fallback in this phase

## Validation in This Phase

Phase 2 validation is intentionally honest and limited to:

- isolated install/discovery checks
- isolated extension resolution/loading checks
- prompt-guidance checks with and without an active `subagent` tool
- documentation/baseline checks

It does **not** yet claim a true isolated end-to-end Superpowers workflow test on Pi. That belongs to Phase 3.

## Known Limitations

- **No built-in subagents in Pi core** — isolated Task-style workflows require the documented external setup
- **No `TodoWrite` equivalent in Phase 2** — task tracking falls back to markdown checklists
- **No supported `plan-mode` or `todo` integration yet** — Pi's example extensions exist, but they are not part of the supported Phase 2 baseline
- **No full parity claim** — this phase documents one compatibility baseline, not complete Claude/Codex/OpenCode parity

## Updating

Update all installed Pi packages:

```bash
pi update
```

Update only Superpowers:

```bash
pi update https://github.com/obra/superpowers
```

For local path installs, pull manually:

```bash
cd /path/to/superpowers && git pull
```

## Uninstalling

```bash
pi remove https://github.com/obra/superpowers
```

For local path installs:

```bash
pi remove /path/to/superpowers
```

If you installed the supported external subagent baseline, remove those symlinks separately:

```bash
rm -f ~/.pi/agent/extensions/subagent/index.ts
rm -f ~/.pi/agent/extensions/subagent/agents.ts
rm -f ~/.pi/agent/agents/worker.md
```

## Troubleshooting

### Skills are not showing up

1. Check the package is installed: `pi list`
2. Confirm the package checkout exists under `~/.pi/agent/git/...` if you installed from GitHub
3. Start a fresh Pi session after install

### The agent keeps treating Pi like Claude Code

That usually means the bootstrap extension did not load or Pi needs a fresh session. Restart Pi or run `/reload`.

### The agent wants to use subagents, but plain Pi core is installed

That's outside the plain-Pi baseline. Install the supported external `subagent` setup above, or tell the agent to use `superpowers:executing-plans`.

### `requesting-code-review` dispatches to wrong agent

The superpowers extension translates `superpowers:code-reviewer` references to
the builtin `reviewer` automatically. If you see errors about a missing
`code-reviewer` agent, remove any stale symlink at `~/.pi/agent/agents/code-reviewer.md`
and restart Pi.

## Getting Help

- Report issues: <https://github.com/obra/superpowers/issues>
- Main repository: <https://github.com/obra/superpowers>
- Pi documentation: <https://github.com/mariozechner/pi-coding-agent>
