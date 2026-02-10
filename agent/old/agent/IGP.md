# Instruction Graph Protocol (IGP) — v0.3

## Load‑bearing truths (what Copilot actually honors)

* **Repo‑wide instructions**: `.github/copilot-instructions.md` are consumed by Copilot Chat, Code Review, and the coding agent. Keep build/test/CI “golden commands” here.
* **Path‑specific instructions**: `.github/instructions/**/NAME.instructions.md` with YAML `applyTo:` globs; VS Code + the coding agent use these. If a path‑specific file and repo‑wide file both match, both are used—so avoid contradictory guidance.
* **AGENTS.md** (and provider files like `CLAUDE.md`, `GEMINI.md`) are agent‑only instruction files; the **nearest** one in the tree takes precedence. Use sparingly.
* **Prompt files** (`.github/prompts/*.prompt.md`) are reusable runbooks callable via `/name` or via “Attach context → Prompt…”.
* **VS Code setting**: ensure instruction files are enabled in Chat/code‑gen flows; otherwise repo instructions may be ignored.
* **MCP with the coding agent**: the agent uses **tools** exposed by MCP servers (allowlist them). Treat tool hints as optional capability.

---

## IGP model (MCP‑style, n‑level hierarchy)

Treat each `*.instructions.md` as a **node**. Copilot only requires `applyTo`. Other keys below are **conventions** to form a traversable graph for humans/tools.

```yaml
---
applyTo: "services/api/**"   # REQUIRED for Copilot
role: "feature|component|quality|bootstrap"
id: "api.feature"
children:
  - "./30-api.handlers.instructions.md"
requires:
  - "./50-quality.instructions.md"
toolsPref: ["sql","github"]
gates: ["lint","typecheck","test"]
version: "0.3"
---
```

### Traversal (what “bootstrap” does)

1. Load repo‑wide `.github/copilot-instructions.md`.
2. Collect all matching `*.instructions.md` for the current file/task (Copilot behavior).
3. Print an **ordered outline** of matched nodes plus `children`/`requires`, then proceed.

### Merge & conflict hygiene

* Keep repo‑wide doc **≤ 12 lines** (purpose, stack, golden commands, CI gate). Spend specifics in path‑scoped nodes.
* Prefer **indices over prose**: `*_index.instructions.md` nodes only *route* to leaves with checklists.
* If two nodes disagree, the **leaf** (narrowest `applyTo`) wins; use numeric prefixes in filenames (`00-, 10-, 20-…`) to imply read order when multiple nodes match.

---

## File layout — Minimum viable

```
.github/
  copilot-instructions.md                # repo TL;DR (build/test/CI)
  instructions/
    00-bootstrap.instructions.md         # applies to "**/*" (graph intro)
  prompts/
    bootstrap.prompt.md                  # one-tap: “Reload context”
  chatmodes/
    bootstrap.chatmode.md                # always run bootstrap first
```

> The protocol does not prescribe a fixed topology; **Bootstrap is the only required node**. Add other nodes only if your repository truly needs them.

---

## Copy‑paste previews (production‑ready, short)

### 1) Repo TL;DR (≤12 lines)

`.github/copilot-instructions.md`

```md
# Copilot: Repo TL;DR
Purpose: <one line>. Stack: <lang/framework/runtime/db>.
Golden cmds: build <cmd> · test <cmd> · lint <cmd> · dev <cmd>
CI must pass: <workflow or script>.
Rules: follow exemplars in <paths>; write tests w/ changes; no secrets.
```

### 2) Bootstrap node (applies everywhere)

`.github/instructions/00-bootstrap.instructions.md`

```md
---
applyTo: "**/*"
role: "bootstrap"
children: []  # link downstream nodes when used
gates: ["lint","typecheck","test"]
---

# Bootstrap — Session Start

Do first:
1) Read repo TL;DR + all matching instructions.
2) Print bullets: stack, golden cmds, CI gate.
3) List matched nodes (ordered) with children/requires.
4) If MCP configured, list tool names (no calls).
5) Ask for task if unclear; then proceed.
```

### 5)  Deterministic “Reload context”

`.github/prompts/bootstrap.prompt.md`

```md
---
description: "Reload repo context + list applicable instruction nodes"
---

Task: Rebuild working context for the current scope.

Steps:
1) Read `.github/copilot-instructions.md` + all `.github/instructions/*.instructions.md`.
2) Print bullets: stack, golden cmds, CI gate.
3) List matched nodes (ordered) with children/requires.
4) If MCP exists, list tool names (no calls).
5) Print "Context Ready" checklist.
```

### 6) Optional chat mode (always bootstraps)

`.github/chatmodes/bootstrap.chatmode.md`

```md
---
name: "Bootstrap"
description: "Always rebuild context before answering"
instructions: |
  Always run the Bootstrap Steps before answering.
---
```

### 7) Optional MCP config (agent‑only)

*(configure in your environment/repo settings or keep a reference file like below)*

`mcp/mcp.json`

```json
{
  "clients": [
    { "name": "github", "transport": "stdio", "command": "copilot-mcp-github" },
    { "name": "sql",    "transport": "stdio", "command": "mcp-postgres", "args": ["--dsn","postgres://..."] }
  ]
}
```

---

## Pro tips applied (practical)

* **Avoid conflicts**: push specific rules down to the narrowest `applyTo` leaf; keep repo‑wide ≤ ~12 lines.
* **Globs**: separate patterns with commas; `applyTo: "**/*"` applies everywhere.
* **Whitespace**: Copilot trims aggressively—prefer compact bullets.
* **Review ergonomics**: keep PR hints in leaves; link to exemplars/ADRs.
* **Agent parity**: build/test/CI commands in the TL;DR materially improve Agent tasks.
* **MCP**: list tool names in leaves; keep servers read‑only by default.

---

## Short preview bundle (drop‑in)

**A.** `.github/copilot-instructions.md` (5 lines)

```md
Purpose: Payments svc. Stack: Node 20 + Fastify + pnpm.
Build: pnpm -w build · Test: pnpm -w test · Lint: pnpm -w lint
CI: .github/workflows/ci.yml must pass.
Contrib: follow /services/api exemplars; add tests; no secrets.
```

**C.** `.github/prompts/bootstrap.prompt.md` (reload context)

```md
Rebuild context; list stack, golden cmds, CI gate; show matched nodes.
Stop with “Context Ready”.
```

**D.** (Optional) MCP reference

```json
{ "mcpServers": { "github-mcp-server": { "type":"http", "url":"<readonly-endpoint>", "tools":["*"] } } }
```

---

## v0.3 Enhancement — Required header fields (role, tags, description)

> To standardize discoverability and filtering, **every `*.instructions.md` must include these fields in the frontmatter**, in addition to `applyTo`.

**Required**

* `applyTo`: glob(s) that scope the node.
* `role`: one of `bootstrap | domain-index | feature-index | component | quality | recovery` (extend only if necessary).
* `tags`: 2–5 keywords (e.g., `api`, `backend`, `routing`, `sql`, `testing`, `perf`, `security`, `infra`, `ux`).
* `description`: one‑line, imperative summary (≤120 chars) that explains what this node enforces or routes.

**Optional**

* `id`: stable identifier for cross‑refs.
* `children`, `requires`, `toolsPref`, `gates`, `version`.

### Header schema (template)

```yaml
---
applyTo: "<glob,glob>"
role: "<role>"
tags: ["<k1>","<k2>","<k3>"]
description: "<one‑line summary>"
# optional
id: "<stable-id>"
children: ["./child-a.instructions.md","./child-b.instructions.md"]
requires: ["./quality.instructions.md"]
toolsPref: ["github","sql"]
gates: ["lint","typecheck","test"]
version: "0.3"
---
```

### Enhanced examples (copy‑paste)

**Bootstrap** — `.github/instructions/00-bootstrap.instructions.md`

```md
---
applyTo: "**/*"
role: "bootstrap"
tags: ["graph","bootstrap","global"]
description: "Global bootstrap: load TL;DR, merge matching nodes, print graph + CI gates."
children: []  # link downstream nodes when used
gates: ["lint","typecheck","test"]
version: "0.3"
---
```

> These additions keep the IGP v0.3 structure intact while making nodes **searchable, filterable, and self‑describing** for both humans and tooling.

---

## Generic, topology‑agnostic guidance

* **Bootstrap is mandatory.** It ensures Copilot Chat/Agent can rebuild context deterministically. Every other node type is a pattern you may adopt.
* **Nodes represent scopes, not org charts.** A node can describe a domain, a feature, a component, or any other logical scope you define.
* **Roles are descriptive, not prescriptive.** Start with `bootstrap | domain-index | feature-index | component | quality | recovery` and extend if your repo needs different shapes.
* **Headers are standardized.** Every node must include `applyTo`, `role`, `tags`, and `description` so humans and tools can filter and navigate.
* **Graph grows organically.** Add or remove nodes without breaking the protocol; only the Bootstrap contract stays stable.
* **Consistency beats completeness.** A few small, high‑signal leaves outperform a massive, generic instruction file.

## Adding new `*.instructions.md` files — generic guidance (no examples)

This protocol keeps the space open—**only Bootstrap is required**. Teams can add more instruction nodes over time without prescribing a fixed topology. Use the guidance below to author nodes consistently, without binding to specific folders or stacks.

### 1) Where to place files

* Put instruction nodes under a dedicated instructions directory inside the repository’s configuration area (e.g., `.github/instructions/`).
* Name files meaningfully and, if ordering matters, prefix with two digits (e.g., `00-`, `10-`, `20-`) to make merge order predictable when multiple nodes match.

### 2) Frontmatter contract (required + optional)

Each node **must** declare a minimal header so both humans and tools can discover and filter it:

* `applyTo`: one or more globs that define the node’s scope (keep as narrow as practical).
* `role`: one of `bootstrap | domain-index | feature-index | component | quality | recovery` (extend only if your org standardizes new roles).
* `tags`: 2–5 concise keywords.
* `description`: one‑line, imperative summary (≤120 chars).

Optional but useful:

* `id` (stable identifier), `children`, `requires`, `toolsPref`, `gates`, `version`, `status` (`draft|live|deprecated`), `owner` (team or person).

> Keep headers machine‑friendly (YAML), one line per field, and avoid long prose—Copilot ignores most whitespace and prefers concise signals.

### 3) Recommended node body (one page, max)

Use terse sections in this order:

* **Objectives** — 1–3 bullets on what the node enforces.
* **Patterns/Rules** — short, testable guardrails.
* **Tooling callbook (if relevant)** — name tools only; avoid runtime instructions if your environment doesn’t guarantee them.
* **Checks** — 3–5 verifiable items (e.g., run gates, confirm artifacts exist).
* **Change boundaries** — what can/can’t be altered under this scope.
* **PR etiquette** — naming, title style, and evidence expectations.

### 4) Scoping and overlap

* Prefer **narrow** `applyTo` scopes to minimize conflicts.
* If two nodes could apply, the **narrower scope** should win. Use numeric filename prefixes to define read order when scopes are similar.
* Do not copy repo‑wide rules into leaves. Point back to the TL;DR instead.

### 5) Versioning & lifecycle

* Include `version` in the header and update it when semantics change.
* Use `status: draft|live|deprecated`. If deprecating, add `replacedBy: <id>`.
* Keep a lightweight changelog entry in commit messages; the node should remain ≤ one page.

### 6) Quality gates & security

* Reuse common `gates` names in headers (e.g., `lint`, `typecheck`, `test`) so Bootstrap and tooling can render a uniform checklist.
* Never embed secrets, tokens, or environment details in nodes. Reference secure storage or org policy docs instead.

### 7) Bootstrap integration

* The required Bootstrap node will read the TL;DR and any nodes whose `applyTo` match the current scope, then print a compact **graph snapshot** (matched nodes + their relations) and the **CI/gates** summary.
* Do not depend on Bootstrap to call external tools; it should only **list** capabilities (e.g., MCP tool names) so Chat and Agents remain deterministic.

### 8) Governance & ownership

* Add `owner:` in the header and align it with repository CODEOWNERS.
* Establish a periodic review cadence (e.g., monthly) to prune stale nodes and tags.
* Keep tag vocabulary short and reusable to improve discovery.

This guidance lets teams grow an instruction graph organically while keeping the protocol consistent and future‑proof.

---

## Additional `*.instructions.md` templates (ready to add)

> Drop any of these into `.github/instructions/` as your graph grows. Keep bodies ≤ one page; adjust `applyTo`, `tags`, and checks to your repo.

**`50-quality.instructions.md`**

```md
---
applyTo: "**/*"
role: "quality"
tags: ["testing","quality","coverage"]
description: "Quick quality gates for lint/type/test and coverage thresholds."
gates: ["lint","typecheck","test"]
version: "0.3"
---

# Quality Gates
- Keep coverage ≥ threshold (see package.json).
- Pre‑PR: run gates in order: lint → typecheck → tests.
```

**`90-recovery.instructions.md`**

```md
---
applyTo: "**/*"
role: "recovery"
tags: ["rollback","hotfix","incident"]
description: "Fix‑forward and rollback playbooks; keep CI green while reverting safely."
version: "0.3"
---

# Recovery
- If a change breaks CI: revert the smallest set; keep tests passing.
- Document rollback PR with cause, scope, and next steps.
```

**`40-security.instructions.md`**

```md
---
applyTo: "**/*"
role: "security"
tags: ["security","secrets","sast","deps"]
description: "Security expectations and lightweight pre‑PR checks."
gates: ["scan","deps"]
version: "0.3"
---

# Security Checks
- No secrets/tokens in code or configs.
- Run dependency audit and static scan jobs; fix or suppress with rationale.
```

**`40-perf.instructions.md`**

```md
---
applyTo: "apps/**/src/**/*.{ts,tsx,js,jsx}"
role: "perf"
tags: ["performance","budget","web"]
description: "Small perf budgets and verification steps for user‑facing code."
version: "0.3"
---

# Performance
- Respect bundle budgets; note deltas in PR if exceeded and why.
- Add a perf note for significant UI changes (timings, screenshots as needed).
```

**`35-docs.instructions.md`**

```md
---
applyTo: "docs/**"
role: "docs"
tags: ["docs","adr","guides"]
description: "Authoring rules for docs and ADRs; keep changes traceable."
version: "0.3"
---

# Docs
- Keep one topic per page; deprecate/replace via ADR links.
- Validate code samples and update references.
```

**`35-api.contracts.instructions.md`**

```md
---
applyTo: "**/openapi/**/*.{yaml,yml,json}"
role: "component"
tags: ["api","contracts","spec"]
description: "Contract hygiene for API specs; versioning and validation."
version: "0.3"
---

# API Contracts
- Lint/validate spec; update changelog; bump version on breaking changes.
- Sync generated clients/schemas where applicable.
```

**`35-data.sql.instructions.md`**

```md
---
applyTo: "analytics/sql/**/*.{sql,md}"
role: "component"
tags: ["data","sql","models"]
description: "Data/SQL authoring rules; modeling, tests, and reviews."
toolsPref: ["sql"]
version: "0.3"
---

# Data/SQL
- Prefer idempotent migrations; document assumptions.
- Add tests/validation for joins and aggregations.
```

**`35-infra.iac.instructions.md`**

```md
---
applyTo: "infra/**/*.{tf,tfvars,yaml,yml}"
role: "infra"
tags: ["infra","iac","cicd"]
description: "Infrastructure as Code guardrails; plans, reviews, and rollbacks."
version: "0.3"
---

# IaC
- Generate and attach plans in PRs; peer review required for changes.
- Keep rollback notes and state migration steps alongside changes.
```

**`35-ux.accessibility.instructions.md`**

```md
---
applyTo: "apps/**/src/**/*.{tsx,jsx}"
role: "quality"
tags: ["ux","a11y","ui"]
description: "Accessibility and UX checklist for interactive surfaces."
version: "0.3"
---

# A11y & UX
- Ensure labels/roles/tab order; include screenshots for significant UI changes.
- Add aria attributes where appropriate; verify keyboard navigation.
```

**`35-tests.e2e.instructions.md`**

```md
---
applyTo: "**/e2e/**/*"
role: "quality"
tags: ["testing","e2e"]
description: "End‑to‑end test authoring and stability rules."
version: "0.3"
---

# E2E
- Keep tests deterministic; stub external services.
- Capture critical flows; parallelize safely; record flake triage notes.
```

**`35-l10n.i18n.instructions.md`**

```md
---
applyTo: "apps/**/src/**/*.{ts,tsx,js,jsx}"
role: "component"
tags: ["l10n","i18n"]
description: "Localization/internationalization expectations for UI code."
version: "0.3"
---

# L10n/i18n
- Externalize strings; avoid concatenation; verify RTL layouts if applicable.
- Add/update translation keys; include language fallbacks.
```

**`35-packages.types.instructions.md`**

```md
---
applyTo: "packages/types/**"
role: "component"
tags: ["types","contracts","shared"]
description: "Shared type definitions discipline; compatibility and versioning."
version: "0.3"
---

# Shared Types
- Changes require consumers update + typecheck; document breaking changes.
- Keep semantic versioning notes alongside type packages.
```

---

## Role catalog (non‑exhaustive)

Use `role:` to declare the node’s responsibility. This catalog is additive—pick only what your repository needs.

* `bootstrap` — deterministic context rebuild (the only required node).
* `structure` — authoritative map of folders, ownership, and naming.
* `mental-model` — shared mental models for boundaries, contracts, and risk.
* `workflow` — developer flows (branching, PR etiquette, release/backport).
* `quality` — gates like lint/type/test/coverage; a11y/perf/security can be split out.
* `component` — narrow checklists for concrete surfaces (e.g., handlers, UI, specs).
* `recovery` — fix‑forward and rollback playbooks.

> You can introduce additional roles at any time; keep one clear responsibility per node.

## Recommended tags (extend as needed)

`api`, `backend`, `routing`, `sql`, `testing`, `perf`, `security`, `infra`, `ux`, `structure`, `workflow`, `mental-model`.

---

## Project Structure / Mental Models / Workflows — templates to add

Drop any of these into `.github/instructions/` and adjust `applyTo`, `tags`, and checks to your repo.

**`25-structure.project.instructions.md`**

```md
---
applyTo: "**/*"
role: "structure"
tags: ["structure","layout","conventions"]
description: "Authoritative map of directories, ownership, and file naming conventions."
version: "0.3"
---

# Project Structure
- Top-level folders and what belongs in each.
- Naming and placement conventions (files, packages, features).
- Ownership map (link to CODEOWNERS or teams).
- How to add a new module without breaking structure.
```

**`25-mental.models.instructions.md`**

```md
---
applyTo: "**/*"
role: "mental-model"
tags: ["architecture","contracts","ownership"]
description: "Shared mental models: how we think about boundaries, contracts, and change."
version: "0.3"
---

# Mental Models
- Architectural style and boundaries (1–3 bullets).
- Contracts: where types/specs live; how changes flow.
- Risky areas and safe extension seams.
```

**`25-workflows.instructions.md`**

```md
---
applyTo: "**/*"
role: "workflow"
tags: ["devex","branching","release"]
description: "Common developer workflows: branching, testing, releasing, backports."
version: "0.3"
---

# Workflows
- Branching strategy and commit hygiene (short rules).
- Pre-PR checklist (gates, evidence, screenshots where relevant).
- Release flow (tags, changelog, backports) in 5 lines or less.
```

> These nodes make the repo’s structure, mental models, and workflows first‑class and searchable, while keeping **Bootstrap** the only required element of the protocol.