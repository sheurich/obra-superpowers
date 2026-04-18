# Pi Agent Profiles for Superpowers

This directory contains Pi-specific agent profiles used by the documented Superpowers compatibility path.

## Included profile

- `code-reviewer.md` — dedicated review agent used by `requesting-code-review` and the supported Phase 2 subagent-based review path

## Important scope note

This repository does **not** ship the `subagent` tool or a full Pi agent pack.

The supported Phase 2 isolated workflow pairs this file with:
- Pi's upstream `examples/extensions/subagent` extension
- the general-purpose `worker` agent from that setup

`code-reviewer.md` complements that external setup. It does not provide subagent support by itself.

## Installation

Install the bundled review profile into your Pi user agents directory:

```bash
mkdir -p ~/.pi/agent/agents
ln -sf ~/.pi/agent/git/github.com/obra/superpowers/.pi/agents/code-reviewer.md ~/.pi/agent/agents/code-reviewer.md
```

If Superpowers is installed from a local path, replace the source path accordingly.

See `.pi/INSTALL.md` or `docs/README.pi.md` for the full supported Phase 2 setup.
