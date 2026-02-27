# Pi Agent Profiles for Superpowers

This directory contains Pi-specific agent profiles used by Superpowers subagent workflows.

## Included profiles

- `implementer.md` — executes one scoped plan task, tests it, self-reviews, and reports results.
- `spec-reviewer.md` — verifies strict requirement compliance (nothing missing, nothing extra).
- `code-quality-reviewer.md` — reviews maintainability, test quality, and risk after spec review.
- `code-reviewer.md` — used by `requesting-code-review` and related review workflows.

## Installation

Install these profiles into your Pi user agents directory:

```bash
mkdir -p ~/.pi/agent/agents
for profile in implementer spec-reviewer code-quality-reviewer code-reviewer; do
  ln -sf ~/.pi/agent/git/github.com/obra/superpowers/.pi/agents/${profile}.md ~/.pi/agent/agents/${profile}.md
done
```

If Superpowers is installed from a local path, replace the source path accordingly.

## Verify

```bash
ls ~/.pi/agent/agents/{implementer,spec-reviewer,code-quality-reviewer,code-reviewer}.md
```
