# Pi Agent Profiles for Superpowers

This directory is intentionally empty. Review dispatch on Pi uses the builtin
`reviewer` agent from pi-subagents, which inherits the session model via
`subagents.agentOverrides` in settings.json.

The superpowers extension translates `superpowers:code-reviewer` references in
skills to the builtin `reviewer` automatically.

## Why not a custom agent?

User-defined agents in `~/.pi/agent/agents/` cannot inherit the parent session's
model. The `agentOverrides` mechanism only applies to builtin agents. A custom
`code-reviewer.md` without a hardcoded model falls back to bare Anthropic (which
may lack credentials in subagent contexts). The builtin `reviewer` avoids this
entirely.
