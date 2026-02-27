# Superpowers for Pi

> **Experimental.** Pi support is new. Report issues at <https://github.com/obra/superpowers/issues>.

Complete guide for using Superpowers with [pi](https://github.com/mariozechner/pi-coding-agent).

## Quick Install

```bash
pi install https://github.com/obra/superpowers
```

Pi clones the repository and discovers all skills from the `skills/` directory automatically. Superpowers also ships a package-managed Pi bootstrap extension at `.pi/extensions/bootstrap.ts` that injects deterministic tool-mapping guidance on each prompt. For subagent-based workflows, install the bundled agent profiles from `.pi/agents/`.

## Installation Options

### Prerequisites

- [Pi](https://github.com/mariozechner/pi-coding-agent) installed
- Git

### Option A: Git Package (recommended)

```bash
pi install https://github.com/obra/superpowers
```

This clones to `~/.pi/agent/git/github.com/obra/superpowers/` and adds the package to `~/.pi/agent/settings.json`.

### Option B: Local Path

If you already have a local clone:

```bash
pi install /path/to/superpowers
```

### Verify Installation

Check the package appears:

```bash
pi list
```

Then start pi and type `/skill:brainstorming` to confirm skills load.

### Configure Required Subagent Profiles

Some Superpowers workflows use multiple subagent profiles.

| Agent profile | Used by |
|---|---|
| `implementer` | `subagent-driven-development` task implementation role |
| `spec-reviewer` | `subagent-driven-development` spec compliance review role |
| `code-quality-reviewer` | `subagent-driven-development` code quality review role |
| `code-reviewer` | `requesting-code-review` and related review workflows |

Pi packages do not auto-install agent profiles, so install the bundled profiles once:

If installed from GitHub:

```bash
mkdir -p ~/.pi/agent/agents
for profile in implementer spec-reviewer code-quality-reviewer code-reviewer; do
  ln -sf ~/.pi/agent/git/github.com/obra/superpowers/.pi/agents/${profile}.md ~/.pi/agent/agents/${profile}.md
done
```

If installed from a local path:

```bash
mkdir -p ~/.pi/agent/agents
for profile in implementer spec-reviewer code-quality-reviewer code-reviewer; do
  ln -sf /path/to/superpowers/.pi/agents/${profile}.md ~/.pi/agent/agents/${profile}.md
done
```

Verify:

```bash
ls ~/.pi/agent/agents/{implementer,spec-reviewer,code-quality-reviewer,code-reviewer}.md
```

## Usage

### Finding Skills

Pi lists available skills at startup in the `<available_skills>` section of the system prompt. The agent sees skill names and descriptions automatically.

### Loading a Skill

Three ways:

1. **Automatic** — the agent reads a matching skill when a task fits its description
2. **Command** — type `/skill:brainstorming` (or any skill name)
3. **Direct** — the agent uses `read` on the SKILL.md file

### Personal Skills

Create skills in `~/.pi/agent/skills/`:

```bash
mkdir -p ~/.pi/agent/skills/my-skill
```

Create `~/.pi/agent/skills/my-skill/SKILL.md`:

```markdown
---
name: my-skill
description: Use when [condition] - [what it does]
---

# My Skill

[Your skill content here]
```

### Project Skills

Create project-specific skills in `.pi/skills/` within your project.

## Tool Mapping

Skills are written for Claude Code. Pi equivalents:

| Claude Code | Pi | Notes |
|---|---|---|
| `Skill` tool | `read` tool / `/skill:name` | Pi loads skill content via `read` |
| `TodoWrite` | — | No direct equivalent; use markdown checklists |
| `Task` with subagents | `subagent` tool | Requires a subagent extension and matching agent profiles (for example `code-reviewer`) |
| `Read` | `read` | Same |
| `Write` | `write` | Same |
| `Edit` | `edit` | Same |
| `Bash` | `bash` | Same |

### Phase 2 Bootstrap Workflow Mapping

The bootstrap extension (`.pi/extensions/bootstrap.ts`) injects a fixed mapping block before each agent run so core Superpowers assumptions stay explicit in Pi:

| Superpowers expectation | Pi bootstrap behavior | Caveat |
|---|---|---|
| `using-superpowers` should be active at session start | Loads `skills/using-superpowers/SKILL.md`, strips frontmatter, appends content to the system prompt | If the skill file is missing, bootstrap no-ops |
| Claude `Skill` tool is available | Maps to `/skill:<name>` or direct `read` on `SKILL.md` | Model still decides when to load other skills |
| Claude `Task` tool supports delegation | Maps to Pi `subagent` when available | Depends on harness extensions; Pi core has no built-in subagent |
| `TodoWrite` checklist workflow exists | Maps to markdown checklist output | No native interactive task list UI |

### Subagent Differences

Pi core does not include built-in subagents. If your Pi harness provides a `subagent` tool, it maps to Claude Code's `Task` behavior.

Pi `subagent` tools typically provide three modes:

- **single** — one agent, one task (closest to Claude Code's `Task`)
- **parallel** — multiple independent tasks
- **chain** — sequential tasks where each receives prior output

## Architecture

Pi's package system discovers superpowers resources through package metadata:

1. `pi install` clones the repo
2. Pi reads this repository's `package.json` `pi` manifest (`skills` + `.pi/extensions`)
3. Skills appear in the system prompt's `<available_skills>` XML
4. `.pi/extensions/bootstrap.ts` autoloads and injects deterministic tool-mapping guidance
5. The agent loads full skill content on demand via `/skill:<name>` or `read`

No external plugin wrapper is required.

### Skill Locations

Pi discovers skills from multiple locations. On name collision, the first skill found wins. See [pi's skill documentation](https://github.com/mariozechner/pi-coding-agent/blob/main/docs/skills.md) for authoritative loading order.

- **Global** — `~/.pi/agent/skills/`
- **Project** — `.pi/skills/`
- **Settings/Packages** — `skills` array and installed packages
- **CLI** — `--skill <path>`

### Harness-Specific Files

Pi-specific resources live in `.pi/` in this repository:

- `.pi/INSTALL.md`
- `.pi/agents/implementer.md`
- `.pi/agents/spec-reviewer.md`
- `.pi/agents/code-quality-reviewer.md`
- `.pi/agents/code-reviewer.md`
- `.pi/extensions/bootstrap.ts`

## Updating

```bash
pi update
```

`pi update` updates all installed packages. To update only Superpowers:

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


## Troubleshooting

### Skills not found

1. Check package is installed: `pi list`
2. Check skills exist: `ls ~/.pi/agent/git/github.com/obra/superpowers/skills/`
3. Verify each skill has a `SKILL.md` with valid frontmatter

### Skill not triggering automatically

Pi includes skill descriptions in the system prompt but relies on the model to decide when to load them. Use `/skill:name` to load explicitly.

### Tool mapping confusion

If the agent attempts a Claude Code tool that doesn't exist in pi, remind it of the mapping above.

## Known Differences from Claude Code

- **No `TodoWrite`** — Pi has no built-in task tracking tool. Skills that use `TodoWrite` checklists produce markdown checklists instead.
- **No hooks system** — Pi has no Claude-style hooks, so Superpowers uses a package-managed extension (`.pi/extensions/bootstrap.ts`) to inject a deterministic bootstrap block at `before_agent_start`.
- **Package install required** — Superpowers for Pi is supported via `pi install` (git URL or local path) so both skills and `.pi/extensions/bootstrap.ts` load together.
- **Skill loading** — Claude Code has a dedicated `Skill` tool. Pi uses `read` on SKILL.md files. Functionally equivalent, syntactically different.
- **Subagent model** — Pi core does not include built-in subagents. If your harness provides a `subagent` tool, Claude Code's `Task` usually maps to single mode.
- **Agent profiles** — Pi packages do not auto-install agent profiles. Superpowers ships required Pi profiles in `.pi/agents/`; install them in `~/.pi/agent/agents/`.

## Getting Help

- Report issues: <https://github.com/obra/superpowers/issues>
- Main documentation: <https://github.com/obra/superpowers>
- Pi documentation: <https://github.com/mariozechner/pi-coding-agent>
