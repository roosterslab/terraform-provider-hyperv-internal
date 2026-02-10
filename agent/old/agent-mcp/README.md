# agent-mcp bundle

This folder hosts agent-facing docs and quick references so coding agents can operate safely and efficiently in this repo.

Contents
- AGENTS.md: Rules of engagement, golden commands, and success criteria.
- Reference links into IGP and operating rules under `terraform-provider-hypervapi-v2/agent/*`.

Usage
- Agents should load AGENTS.md at session start, then traverse linked instruction nodes in `terraform-provider-hypervapi-v2/agent/` per IGP.
- Prefer running demo Test.ps1 scripts for validation over writing ad-hoc checks.

