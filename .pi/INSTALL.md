# Installing Superpowers for Pi

## Prerequisites

- [Pi](https://github.com/mariozechner/pi-coding-agent) installed
- Git

## Installation

```bash
pi install https://github.com/obra/superpowers
```

Pi clones the repo, discovers skills from `skills/`, and autoloads `.pi/extensions/bootstrap.ts` via the package manifest.

### Alternative: Local Clone

If you already have a local clone:

```bash
pi install /path/to/superpowers
```

## Verify

Check that the package appears:

```bash
pi list
```

Then start pi and use `/skill:brainstorming` to confirm skills load.

## Configure Required Subagents

Some Superpowers workflows use multiple subagent profiles:

- `implementer`
- `spec-reviewer`
- `code-quality-reviewer`
- `code-reviewer`

Pi packages do not install agent profiles automatically, so install the bundled profiles once.

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

## Updating

Update superpowers:

```bash
pi update https://github.com/obra/superpowers
```

Or pull manually if using a local path:

```bash
cd /path/to/superpowers && git pull
```

## Uninstalling

```bash
pi remove https://github.com/obra/superpowers
```

Or, if installed from a local path:

```bash
pi remove /path/to/superpowers
```
