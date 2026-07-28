Review the current Kiln work package before closeout.

Use the `kiln-integrity-review` skill.

When project-local specialist agents are available and trusted, delegate read-only reviews to:

- `kiln-otp-reviewer` when the diff changes processes, supervisors, tasks, ports, messages, cancellation, or restart behavior;
- `kiln-integrity-reviewer` for every material implementation work package.

The main coding agent remains responsible for the final decision and any fixes.

Do not ask specialist agents to edit files. Do not implement optional findings unless they support the current work-package objective.

Return one combined report with blocking findings, material risks, invariant effects, missing architecture decisions, unsupported claims, and optional improvements kept separate.
