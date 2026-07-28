---
name: kiln-evidence-closeout
description: Closes a Kiln work package with current verification evidence. Use after implementation to inspect the diff, run required checks, map evidence to acceptance criteria, and report unknowns without overstating completion.
compatibility: Kiln repository with Git, Bash, Vale, Elixir, and project scripts.
---

# Kiln Evidence Closeout

Use this skill after implementation and before a completion claim or pull-request readiness change.

## Procedure

1. Read the current work-package plan.
2. Capture repository state:

   ```bash
   git status --short --branch
   git rev-parse HEAD
   git diff --stat <base>...HEAD
   git diff <base>...HEAD
   ```

3. Map each changed file to the work-package objective.
4. Run the narrowest behavior checks for the changed modules.
5. Run:

   ```bash
   scripts/check
   ```

6. Request specialist review when the change touches:

   - OTP lifecycle or supervision;
   - persistence or replay;
   - security or permissions;
   - project invariants;
   - provider or extension boundaries.

7. Record one evidence item for each acceptance criterion.
8. Mark each criterion `Pass`, `Fail`, `Not run`, or `Not applicable`.
9. Update the completion record in the work-package plan.
10. Inspect the repository state again after documentation updates.

## Evidence rules

Evidence MUST include:

- command;
- exit status;
- current commit or repository state;
- behavior evaluated;
- output location or concise result;
- collector identity when evidence came from another agent.

A passing test is evidence only for behavior that the test evaluates.

A reviewer statement is not execution evidence.

A previous command result becomes stale when relevant source or configuration changes after the command.

## Completion vocabulary

Use:

- `Complete` only when all required criteria pass and required verification ran;
- `Implemented but unverified` when source changes exist but required checks did not run;
- `Incomplete` when required behavior or evidence is missing;
- `Blocked` when an external condition prevents progress.

## Output format

```text
Work package:
Branch:
Commit:
Diff reviewed: Yes | No

Acceptance status:
- <criterion>: Pass | Fail | Not run | Not applicable
  Evidence: <evidence ID and result>

Verification:
- <command>: exit <status>; behavior evaluated

Specialist review:
- reviewer and verdict, or Not required with reason

Failures and warnings:
- ...

Unknowns:
- ...

Exclusions:
- ...

Completion statement:
- Complete | Implemented but unverified | Incomplete | Blocked
```

## Rules

- Do not fix unrelated issues during closeout.
- Do not rerun only a narrow test after a final source change when the full gate is required.
- Do not omit an intentional negative test from the evidence record.
- Do not claim the branch is ready for `main` while a stacked prerequisite remains unmerged.
