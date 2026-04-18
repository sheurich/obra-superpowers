# Installing Superpowers for Pi

## 1. Install the package

```bash
pi install https://github.com/obra/superpowers
```

That gives you the **plain Pi core baseline** for Phase 2:
- package install/discovery
- automatic Superpowers bootstrap injection
- planning and other non-subagent workflows

## 2. Install the supported subagent setup if you want isolated execution/review

Phase 2 does **not** bundle subagent support. The documented compatibility baseline uses Pi's upstream `examples/extensions/subagent` extension plus:
- the upstream `worker` agent
- Superpowers's bundled `code-reviewer` agent

### Install Pi's upstream `subagent` example

```bash
PI_INSTALL_DIR="$(node -p 'require("node:path").dirname(require.resolve("@mariozechner/pi-coding-agent/package.json"))')"
SUBAGENT_DIR="$PI_INSTALL_DIR/examples/extensions/subagent"

mkdir -p ~/.pi/agent/extensions/subagent
ln -sf "$SUBAGENT_DIR/index.ts" ~/.pi/agent/extensions/subagent/index.ts
ln -sf "$SUBAGENT_DIR/agents.ts" ~/.pi/agent/extensions/subagent/agents.ts

mkdir -p ~/.pi/agent/agents
ln -sf "$SUBAGENT_DIR/agents/worker.md" ~/.pi/agent/agents/worker.md
```

### Install Superpowers's bundled `code-reviewer`

If installed from GitHub:

```bash
mkdir -p ~/.pi/agent/agents
ln -sf ~/.pi/agent/git/github.com/obra/superpowers/.pi/agents/code-reviewer.md ~/.pi/agent/agents/code-reviewer.md
```

If installed from a local path:

```bash
mkdir -p ~/.pi/agent/agents
ln -sf /path/to/superpowers/.pi/agents/code-reviewer.md ~/.pi/agent/agents/code-reviewer.md
```

Start a fresh Pi session after adding the external setup, or run `/reload`.

## 3. What this phase does not install

Phase 2 does **not** make Pi's example `todo` or `plan-mode` extensions part of the supported setup.
`TodoWrite` still falls back to markdown checklists.

## Verify

```bash
pi list
ls ~/.pi/agent/extensions/subagent/index.ts
ls ~/.pi/agent/agents/worker.md
ls ~/.pi/agent/agents/code-reviewer.md
```

## Updating

Update only Superpowers:

```bash
pi update https://github.com/obra/superpowers
```

Or update all packages:

```bash
pi update
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
