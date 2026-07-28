---
name: kiln-integrity-review
description: Reviews a Kiln plan or diff for project drift, invariant violations, unsupported claims, hidden scope expansion, and architecture changes that require an ADR. Use before merge and after material design changes.
compatibility: Read-only review of the Kiln repository.
---

# Kiln Integrity Review

This skill reviews preservation of project intent and architecture. It does not implement fixes.

## Inputs

Collect:

- work-package plan;
- current branch and commit;
- diff against the intended base;
- applicable ADRs;
- `docs/PROJECT-INVARIANTS.md`;
- test and command evidence;
- completion report when available.

## Review procedure

1. Confirm that the diff serves one work-package objective.
2. Map each material change to a requirement and acceptance criterion.
3. Check each applicable `KILN-INV-*` invariant.
4. Identify architecture decisions that lack an ADR.
5. Separate current behavior from proposed behavior.
6. Check that interfaces, persistence, supervision, and evidence ownership remain in the intended layers.
7. Check for speculative abstractions, compatibility paths, plugin hooks, or configuration that the work package does not need.
8. Check that development-agent files are not represented as product runtime components.
9. Check that completion claims cite current evidence.
10. Check the final diff for unrelated changes.

## Required output

Use this structure:

```text
Verdict: Pass | Block | Pass with non-blocking findings

Blocking findings:
- [path or evidence] finding, affected requirement or invariant, required correction

Material risks:
- [path or evidence] risk, impact, cheapest verification

Preserved invariants:
- KILN-INV-...

Threatened invariants:
- KILN-INV-... or None observed

ADR required:
- decision or None observed

Unsupported claims:
- claim and missing evidence or None observed

Scope drift:
- change and reason it is outside the work package or None observed

Optional improvements:
- clearly non-blocking suggestions

Unknowns:
- unknown and cheapest reliable verification
```

## Rules

- Do not edit files.
- Do not turn style preferences into blocking findings.
- Do not require abstractions for hypothetical future needs.
- Do not report a risk without the affected mechanism.
- Do not call a requirement satisfied without evidence.
- Do not approve an invariant change without a superseding ADR.
