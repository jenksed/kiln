Close the current Kiln work package.

Load and follow the `kiln-evidence-closeout` skill.

Inspect the full diff against the intended base. Run narrow behavior checks, then run `scripts/check`.

When the project-local verifier is available and trusted, ask `kiln-verifier` to run an independent non-mutating verification pass. Treat its report as supplied evidence and identify the collector.

Update the work-package completion record with:

- acceptance status;
- evidence IDs;
- exact commands and exit statuses;
- current commit and repository state;
- failures and warnings;
- remaining unknowns and exclusions;
- specialist review results;
- one accurate completion statement.

Do not report the branch ready for `main` while a prerequisite pull request remains unmerged.
