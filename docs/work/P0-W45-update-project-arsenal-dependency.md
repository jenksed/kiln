# P0-W45: Update Project Arsenal dependency to GC01 main

**Document type:** Work-package record (governance / dependency upgrade)
**Status:** Accepted
**Parent work:** P0-W series (governance / development-process authority)
**Branch:** `work/p0-w45-update-arsenal-pin`
**Depends on:** PR #25 (GC01 contract hardening) merged at
`980a58d331f4ed0679e6ae306b9d55b2ee21d179` in `jenksed/project-arsenal`;
the P0-W39 read-only submodule dependency model recorded at
`docs/work/P0-W39-adopt-project-arsenal-dependency.md`; the P0-W44
authorization simplification recorded at
`docs/work/P0-W44-simplify-authorization-boundaries.md`.

## Objective

Advance Kiln's pinned Project Arsenal development-agent dependency
from `ecc8797d45447060b0c4aacd8efb6b1909e9e690` (P0-W39 adoption)
to `980a58d331f4ed0679e6ae306b9d55b2ee21d179` (post-GC01
canonical main). The upstream transition spans 31 Project
Arsenal commits and includes changes to capability-contract 2.2,
compiler/bench infrastructure, the repository-truth package, the
GC01 governance/source-model machinery, and generated
lockfile/package identities.

The dependency upgrade is the sole change. No Kiln runtime, P1-S02
product code, migrations, runtime schemas, or implementation
authorization is modified. No Arsenal source is vendored or
copied into Kiln.

## Observed current state

| Observation | Evidence | Result |
| --- | --- | --- |
| Project Arsenal canonical `main` after GC01 | `980a58d331f4ed0679e6ae306b9d55b2ee21d179` | observed (commit `Merge pull request #25 from jenksed/agent/governance-artifact-roles`) |
| Project Arsenal canonical `main` before P0-W45 | `ecc8797d45447060b0c4aacd8efb6b1909e9e690` (P0-W39 pin) | observed |
| P0-W45 branch | `work/p0-w45-update-arsenal-pin` based on `origin/main` `d3af751ebc25da04e7d3e3380dc5dbd601c1a42b` (P0-W44 merge) | observed |
| P0-W45 commit count vs origin/main | 1 commit (`P0-W45: Update Project Arsenal dependency pin to GC01 main`, head `411632c…`) | observed |
| Kiln gitlink for `.claude/dependencies/project-arsenal` pre-P0-W45 | `ecc8797d45447060b0c4aacd8efb6b1909e9e690` | observed |
| Kiln gitlink for `.claude/dependencies/project-arsenal` post-P0-W45 | `980a58d331f4ed0679e6ae306b9d55b2ee21d179` | observed |
| `.arsenal.lock` plan digest pre-P0-W45 | `sha256:468117f9c6397003522b62c1e7db6d4869a7cbfe0ed7614c8bb9244d9e91059d` | observed at P0-W39 pin |
| `.arsenal.lock` plan digest post-P0-W45 (derived from pinned upstream) | `sha256:8284fab44cd6f27d7e5533f79b6b64f5feffb1590ae569c623983180e4c76c9f` | observed at GC01 main |
| `repository-truth` package digest pre-P0-W45 | `sha256:1c6f8c72582c10d53475c0c865a2ee31fce20a2bbe7582198f510091470f3f84` | observed at P0-W39 pin |
| `repository-truth` package digest post-P0-W45 (derived from pinned upstream) | `sha256:741905b11ff97ec44da34cf17a3f9ab418b3973103e7aa21c6d2bf3b9fb1e310` | observed at GC01 main |
| Tracked symlink `.claude/skills/repository-truth` | resolves to `.claude/dependencies/project-arsenal/distribution/agent-skills/repository-truth` | observed |
| `repository-truth` package authority at the new pin | mutation class `read-only`; required authority `filesystem.read`, `git.read`; forbidden authority `filesystem.write`, `network.write`, `git.write`, `tracker.write`, `secrets.read`, `cloud.remote`, `production.mutate`; invocation `agent`; compatibility requires repository read access | observed at `distribution/agent-skills/repository-truth/arsenal-manifest.json` |
| Upstream `HEAD` at adoption | a GitHub merge commit; pinning combines a commit SHA and the lockfile digests, both checked deterministically | observed at P0-W39, still true at P0-W45 |
| 31 upstream commits reviewed | `f829d6c ARS-01A` through `980a58d Merge pull request #25`, spanning ARS-01A through ARS-11, Arsenal protocol/I/O refactor, PR #24, and GC01 base + 3 contract-consistency repair commits | observed |
| Kiln runtime dependency on Arsenal | none (`grep -rn 'arsenal_governance\|arsenal_source_model\|arsenal_source_validate' lib/ test/ scripts/` returns no matches outside the dependency verifier) | observed |
| Kiln source-model consumer | none (no `load_source_model()` call site introduced) | observed |
| Composite-source constraint (`asset.identity`) | preserved: the merged-registry pattern (`arsenal/registry.json` + `arsenal/registry.d/*.json`) is unchanged at the upstream side; no Kiln consumer traces `asset.identity` through the GC01 source model | observed |

## Assumptions and unknowns

- The user-owned downstream copy of the source-model toolchain may be invoked later via an explicitly-scoped work package. P0-W45 establishes only that the new Arsenal revision is a safe dependency; it does not add a source-model consumer.
- The Project Intelligence work-plan branch `agent/project-intelligence-redirection` (HEAD `6393c1a`) still lists `asset.identity` in its PI-00 tracer set. The GC01 source-model ships with `asset.identity` explicitly excluded from any PI-00 tracer until composite-source modeling lands upstream. Reconciling the PI-00 work plan to drop `asset.identity` from its tracer set is a separate, post-merge work package, not part of P0-W45.
- The Project Arsenal canonical `main` may receive additional commits after `980a58d`. Any further pin update requires a new reviewed work package; P0-W45 binds only to the exact reviewed commit.
- Kiln's `scripts/agent-preflight` on macOS bash 3.2 may fail with `candidates[@]: unbound variable` on a `work/p[0-9]+-w[0-9]+-*` branch whose `docs/work/<id>-*.md` plan file has not yet been committed. The pre-flight is recorded to PASS once this plan document has been committed and reviewed locally; the bash 3.2 / `set -u` interaction is itself a separate latent harness defect (see "Future follow-ups" below).

## Requirements

1. Advance the superproject gitlink for `.claude/dependencies/project-arsenal` to exactly `980a58d331f4ed0679e6ae306b9d55b2ee21d179`.
2. Update `scripts/check-project-arsenal-dependency` to bind to the new reviewed pin and to the lockfile digests derived from the pinned upstream (not copied from a prompt).
3. Update `docs/AGENT-ASSET-NOTES.md` to record the new pin and both new digests in the dependency block and in the new "Pin updates" history table.
4. Preserve the P0-W39 trust boundary: Project Arsenal remains untrusted development-agent/reference content; no Kiln runtime depends on any Arsenal module; the `.claude/skills/repository-truth` symlink still resolves inside the pinned submodule to the expected package directory; the upstream installer is not invoked.
5. Do not vendor or copy any Arsenal source into the Kiln repository.
6. Do not add a Kiln source-model consumer in this slice.
7. Do not trace `asset.identity` through the GC01 source model in this slice.
8. Do not modify Kiln runtime implementation, P1-S02 product code, migrations, runtime schemas, or implementation authorization.

## Proposed changes

- Stage the gitlink advance as a single commit-bound update to `.claude/dependencies/project-arsenal`.
- Replace the four pinned literals (`Pinned_Commit`, `Plan_Digest`, `Package_Digest`) in `scripts/check-project-arsenal-dependency` with values derived from the pinned upstream `.arsenal.lock`.
- Replace the four pinned literals in the `docs/AGENT-ASSET-NOTES.md` "project-arsenal" block; append a "Pin updates" subsection listing both P0-W39 (initial) and P0-W45 (GC01 main) entries with the digests that were reviewed at each pin.
- Document the composite-source disposition in source-model notes (already present after GC01) without re-opening GC01's deferred-design decisions.

## Expected files or components

| Path | Status |
| --- | --- |
| `.claude/dependencies/project-arsenal` | gitlink only (superproject mode `160000`, recorded SHA `980a58d…`) |
| `scripts/check-project-arsenal-dependency` | pin/digest literals updated |
| `docs/AGENT-ASSET-NOTES.md` | pin/digest literals updated; "Pin updates" table added |
| `docs/work/P0-W45-update-project-arsenal-dependency.md` | this work-package record (required to satisfy `scripts/agent-preflight` on the branch class) |

No other file in Kiln is touched by P0-W45. The upstream Arsenal
submodule working tree is materialized at `980a58d…` but is not
copied or vendored.

## Acceptance criteria

| ID | Criterion |
| --- | --- |
| P0-W45-AC01 | Superproject gitlink for `.claude/dependencies/project-arsenal` is `160000 980a58d331f4ed0679e6ae306b9d55b2ee21d179 0\t.claude/dependencies/project-arsenal`; `.gitmodules` declares the canonical URL `https://github.com/jenksed/project-arsenal.git` and the same submodule path. |
| P0-W45-AC02 | Materialized submodule `HEAD` is `980a58d331f4ed0679e6ae306b9d55b2ee21d179` and its `remote.origin.url` matches the canonical URL. |
| P0-W45-AC03 | Exactly three Kiln files are changed by P0-W45: the gitlink, the verifier, and the documentation. No Kiln runtime, lib, test, or P1-S02 code is modified. |
| P0-W45-AC04 | `scripts/check-project-arsenal-dependency` exit code is `0` and prints the new pin and both new digests. |
| P0-W45-AC05 | `scripts/validate-agent-assets` exit code is `0` and prints `project-arsenal dependency: verified`. |
| P0-W45-AC06 | `scripts/agent-preflight` exit code is `0` on the exact new kiln HEAD and reports `work kind: planning`, `work package: P0-W45`, and `plan: docs/work/P0-W45-update-project-arsenal-dependency.md`. |
| P0-W45-AC07 | `scripts/test-agent-preflight` exit code is `0`. |
| P0-W45-AC08 | GitHub CI on the exact PR head is green. |
| P0-W45-AC09 | Kiln repository still contains zero matches for `arsenal_governance\|arsenal_source_model\|arsenal_source_validate` in `lib/`, `test/`, or `scripts/` outside the dependency verifier itself. |
| P0-W45-AC10 | Kiln repository still contains zero `load_source_model(` callers. |
| P0-W45-AC11 | No Kiln code references `asset.identity` through any GC01 source-model API. |

## Deterministic verification

The following commands and their expected results constitute the
deterministic verification surface for P0-W45.

```text
# 1. Superproject gitlink equals the reviewed pin
git ls-files --stage .claude/dependencies/project-arsenal
# Expected: 160000 980a58d331f4ed0679e6ae306b9d55b2ee21d179 0	.claude/dependencies/project-arsenal

# 2. .gitmodules binds canonical URL and the expected submodule path
git config -f .gitmodules --get submodule..claude/dependencies/project-arsenal.path
git config -f .gitmodules --get submodule..claude/dependencies/project-arsenal.url
# Expected: .claude/dependencies/project-arsenal
#          https://github.com/jenksed/project-arsenal.git

# 3. Materialized submodule HEAD and remote URL
git -C .claude/dependencies/project-arsenal rev-parse HEAD
git -C .claude/dependencies/project-arsenal config --get remote.origin.url
# Expected: 980a58d331f4ed0679e6ae306b9d55b2ee21d179
#          https://github.com/jenksed/project-arsenal.git

# 4. Lockfile digests at the pinned upstream
python3 -c 'import json; print(json.load(open(".claude/dependencies/project-arsenal/.arsenal.lock"))["plan_sha256"])'
# Expected: sha256:8284fab44cd6f27d7e5533f79b6b64f5feffb1590ae569c623983180e4c76c9f

python3 -c 'import json; d=json.load(open(".claude/dependencies/project-arsenal/.arsenal.lock"))
for c in d["capabilities"]:
    for e in c.get("exports", []):
        if e.get("target")=="agent-skills" and e.get("package_name")=="repository-truth":
            print(e["package_sha256"])'
# Expected: sha256:741905b11ff97ec44da34cf17a3f9ab418b3973103e7aa21c6d2bf3b9fb1e310

# 5. Symlink resolution
readlink -f .claude/skills/repository-truth
# Expected: <root>/.claude/dependencies/project-arsenal/distribution/agent-skills/repository-truth

# 6. Verifier
scripts/check-project-arsenal-dependency
# Expected: pass; pinned commit 980a58d...; plan and pkg digests as above

# 7. Validator
scripts/validate-agent-assets
# Expected: pass; project-arsenal dependency: verified

# 8. Preflight
scripts/agent-preflight
# Expected: pass; work kind: planning; work package: P0-W45;
#           plan: docs/work/P0-W45-update-project-arsenal-dependency.md

# 9. Preflight test suite
scripts/test-agent-preflight
# Expected: pass

# 10. Negative-case checks for the dependency verifier
# Each is restored before the next.
scripts/check-project-arsenal-dependency  # baseline
git update-index --add --cacheinfo 160000,deadbeefdeadbeefdeadbeefdeadbeefdeadbeef,.claude/dependencies/project-arsenal
scripts/check-project-arsenal-dependency  # -> exit 1
git update-index --add --cacheinfo 160000,980a58d331f4ed0679e6ae306b9d55b2ee21d179,.claude/dependencies/project-arsenal
git -C .claude/dependencies/project-arsenal checkout dba4b6460f1f0b040b1f0e39a0c34a69399664a7
scripts/check-project-arsenal-dependency  # -> exit 1
git -C .claude/dependencies/project-arsenal checkout 980a58d331f4ed0679e6ae306b9d55b2ee21d179
sed -i.bak 's|https://github.com/jenksed/project-arsenal.git|https://github.com/attacker/project-arsenal.git|' .gitmodules
scripts/check-project-arsenal-dependency  # -> exit 1
sed -i.bak 's|https://github.com/attacker/project-arsenal.git|https://github.com/jenksed/project-arsenal.git|' .gitmodules
rm -f .gitmodules.bak
mv .claude/dependencies/project-arsenal/.arsenal.lock /tmp/arsenal-lock.bak
scripts/check-project-arsenal-dependency  # -> exit 1
mv /tmp/arsenal-lock.bak .claude/dependencies/project-arsenal/.arsenal.lock
sed -i.bak 's|8284fab44cd6f27d7e5533f79b6b64f5feffb1590ae569c623983180e4c76c9f|0000000000000000000000000000000000000000000000000000000000000000|' scripts/check-project-arsenal-dependency
scripts/check-project-arsenal-dependency  # -> exit 1
sed -i.bak 's|0000000000000000000000000000000000000000000000000000000000000000|8284fab44cd6f27d7e5533f79b6b64f5feffb1590ae569c623983180e4c76c9f|' scripts/check-project-arsenal-dependency
rm -f scripts/check-project-arsenal-dependency.bak
mv .claude/skills/repository-truth .claude/skills/repository-truth.bak
scripts/check-project-arsenal-dependency  # -> exit 1
mv .claude/skills/repository-truth.bak .claude/skills/repository-truth
ln -sfn /nonexistent-path-12345 .claude/skills/repository-truth
scripts/check-project-arsenal-dependency  # -> exit 1
git checkout HEAD -- .claude/skills/repository-truth
scripts/check-project-arsenal-dependency  # -> baseline pass

# 11. No Arsenal source-model consumer in Kiln
grep -rn 'arsenal_governance\|arsenal_source_model\|arsenal_source_validate\|load_source_model(' lib/ test/ scripts/
# Expected: only scripts/check-project-arsenal-dependency matches (if any)
```

GitHub CI on the exact PR head runs:

```text
scripts/agent-preflight
scripts/test-agent-preflight
scripts/validate_first_month_contracts.py
scripts/validate_json_schema_contracts.py
scripts/validate-agent-assets
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test
```

P0-W45 is expected to leave `mix format`, `mix compile`,
`mix xref`, and `mix test` results identical to those on
`origin/main` (no Kiln runtime/lib/test code changes). The
pre-merge state observed locally before P0-W45 was pushed already
satisfies these gates; the upstream Arsenal delta is a separate
project and runs its own CI.

## Required completion Evidence

| Evidence | Source | Result on this slice |
| --- | --- | --- |
| Superproject gitlink equals reviewed pin | `git ls-files --stage .claude/dependencies/project-arsenal` | `160000 980a58d331f4ed0679e6ae306b9d55b2ee21d179 0\t.claude/dependencies/project-arsenal` |
| Materialized submodule HEAD equals reviewed pin | `git -C .claude/dependencies/project-arsenal rev-parse HEAD` | `980a58d331f4ed0679e6ae306b9d55b2ee21d179` |
| Canonical `.gitmodules` URL/path | `git config -f .gitmodules` | `https://github.com/jenksed/project-arsenal.git` at `.claude/dependencies/project-arsenal` |
| Lockfile plan digest at pinned upstream | `python3 -c "json.load(open('.claude/dependencies/project-arsenal/.arsenal.lock'))['plan_sha256']"` | `sha256:8284fab44cd6f27d7e5533f79b6b64f5feffb1590ae569c623983180e4c76c9f` |
| Lockfile `repository-truth` package digest at pinned upstream | `python3 -c` over `capabilities[].exports[]` filtered to `target=agent-skills, package_name=repository-truth` | exactly one match: `sha256:741905b11ff97ec44da34cf17a3f9ab418b3973103e7aa21c6d2bf3b9fb1e310` |
| Tracked symlink resolves inside pinned submodule | `readlink -f .claude/skills/repository-truth` | `<root>/.claude/dependencies/project-arsenal/distribution/agent-skills/repository-truth` |
| `scripts/check-project-arsenal-dependency` exit | direct execution | `0` with the new pin/digests |
| `scripts/validate-agent-assets` exit | direct execution | `0` with `project-arsenal dependency: verified` |
| `scripts/agent-preflight` exit on the exact branch | direct execution | `0` with `work kind: planning`, `work package: P0-W45`, `plan: docs/work/P0-W45-update-project-arsenal-dependency.md` |
| `scripts/test-agent-preflight` exit | direct execution | `0` |
| Negative-case checks for the dependency verifier | per the deterministic verification block | every drift category exits `1`; baseline exits `0` |
| GitHub CI on the exact PR head | `.github/workflows/ci.yml` | green |
| No Arsenal source-model consumer in Kiln | grep across `lib/`, `test/`, `scripts/` | only the dependency verifier (no runtime or product consumer) |

## Explicit exclusions

- No Kiln runtime implementation is integrated, modified, or reintroduced.
- No P1-S02-T01 runtime, test, migration, or schema is touched.
- No P1-S02-T02 or later authorization is granted.
- No new Arsenal source is vendored or copied into Kiln.
- No Kiln code calls `load_source_model()` or any other GC01 source-model API.
- No Kiln code references `asset.identity` through any GC01 source-model API.
- No `validate-agent-assets` semantics are widened beyond the existing dependency-verifier wiring.
- No branch-tracking is configured for the upstream submodule; future pin updates require a new reviewed work package.
- No PR #48 is rehabilitated or referenced.
- No P0-W44 authorization simplification is reversed.
- No GC01 contract-hardening decision is reopened (the composite-source deferral and the asset.identity exclusion remain in force; see `arsenal/source-model.json` `arsenal.registry` notes and `docs/roadmap/post-pr-24-deferred-architecture.md`).

## Future follow-ups

- **Asset-identity composite-source modeling upstream.** P0-W45 ships a dependency upgrade, not the upstream modeling work that would let `asset.identity` be traced through GC01. The PI-00 work plan at `agent/project-intelligence-redirection` (HEAD `6393c1a`) still lists `asset.identity` in its tracer set; reconciling that branch to drop the row is a separate post-merge work package.
- **bash 3.2 / `set -u` interaction in `scripts/agent-preflight`.** On a `work/p[0-9]+-w[0-9]+-*` branch whose `docs/work/<id>-*.md` plan file has not yet been committed, the script fails with `candidates[@]: unbound variable` because the empty candidates array is iterated with `"${candidates[@]}"` while `set -u` is in effect. This is a pre-existing latent harness defect unrelated to P0-W45. A future repair should iterate via `[[ ${#candidates[@]} -gt 0 ]] && for candidate in "${candidates[@]}"; do ...; done` (or equivalent).
- **Any further pin update** to `jenksed/project-arsenal` requires a new reviewed work package; P0-W45 binds only to `980a58d…`.

## Completion record

P0-W45 was executed as a single coherent commit:

```text
P0-W45: Update Project Arsenal dependency pin to GC01 main
```

Local evidence on the exact pinned upstream at commit
`411632cd7a98a9b802a67cacc9bbe8d3422843d3`:

```text
scripts/check-project-arsenal-dependency       pass
scripts/validate-agent-assets                  pass
scripts/test-agent-preflight                  pass
scripts/agent-preflight (on work/p0-w45-update-arsenal-pin,
                          with this plan committed)   pass
negative cases (gitlink SHA, submodule HEAD, URL, lockfile,
                 plan digest, symlink)               all exit 1,
                                                    baseline exit 0
```

GitHub CI on the exact PR head is recorded as green before the
slice is declared ready to merge. P0-W45 ships no Kiln runtime,
product, migration, schema, or authorization change; it is a
dependency-only slice.