---
name: kiln-work-package
description: Starts or continues one Kiln work package. Use before implementation to verify branch naming, load the matching plan, inspect evidence, identify invariants, and define the mutation surface.
compatibility: Kiln repository with Git, Bash, Elixir, and the project scripts.
---

# Kiln Work Package

Use this skill before source-code or material documentation changes.

## Goal

Establish one verified execution coordinate:

```text
work-package ID -> plan -> branch -> requirements -> criteria -> evidence
```

## Procedure

1. Run:

   ```bash
   scripts/agent-preflight
   ```

2. Read:

   - root `AGENTS.md`;
   - the matching file under `docs/work/`;
   - `docs/PROJECT-INVARIANTS.md`;
   - applicable architecture decision records under `docs/decisions/`;
   - the source and tests that currently own the behavior.

3. Record the current state:

   ```bash
   git status --short --branch
   git rev-parse HEAD
   ```

4. State these items before editing:

   - work-package ID;
   - objective;
   - observed current behavior and evidence;
   - applicable invariant IDs;
   - assumptions and unknowns;
   - expected files or components;
   - acceptance criteria to address;
   - narrow verification commands.

5. Inspect dependency direction when a shared module changes:

   ```bash
   mix xref callers Module
   mix xref trace path/to/file.ex
   ```

6. Keep all edits inside one objective. Stop and update the plan when implementation evidence changes the intended boundary.

## Rules

- Do not start implementation from `main`.
- Do not invent a missing plan.
- Do not treat proposed files or behavior as observed.
- Do not change an accepted invariant without a superseding architecture decision record.
- Do not add unrelated cleanup.
- Do not allow a reviewer agent to become a parallel writer.

## Handoff format

When orientation is complete, produce:

```text
Work package:
Branch:
Current commit:
Objective:
Observed:
Applicable invariants:
Unknowns:
Expected mutation surface:
Acceptance criteria in scope:
Narrow checks:
Blocked conditions:
```
