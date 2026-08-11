# Implementation Authorization

**Document type:** Current implementation-authorization authority
**Status:** Accepted
**Current result:** P0-W43 reissues the bounded P1-S02-T01 implementation authorization in `docs/authorizations/P1-S02-T01.authorization` against canonical decision base `1243b8f27a594c9440638964a83b56c74774ba28` and amended Accepted-state plan digest `7dfd3b3ad600e67b110ad6eaec12a06880494958027910289250453c6ade662e`. The amended plan and reissued record become active trusted Repository authority only when P0-W43 integrates on canonical `main`; until then the P0-W42 record remains active. No P1-S02 runtime implementation exists yet; P1-S02-T02 and later remain unauthorized

An accepted plan describes work. An authorization record permits one bounded implementation package to begin. Passing CI, a pull-request body, an available branch, generated code, or an implementation Claim does not substitute for either.

## Commit roles

Five distinct commits appear in every authorization chain. Do not describe them all as "canonical `main`".

| Role | Meaning |
| --- | --- |
| Decision base | The canonical `main` commit the owner reviewed when issuing the record. Recorded as `base_sha`. It does not contain the record it authorizes. |
| Authority source | The trusted commit on canonical `main` that contains the exact accepted-plan and authorization-record blob pair. Located by preflight; must descend from the decision base. |
| Implementation commit | The exact head validated by preflight. `HEAD` on a named local checkout; `KILN_IMPLEMENTATION_COMMIT` in pull-request CI. Must descend from the authority source. |
| Merge-test commit | GitHub's synthetic `refs/pull/<n>/merge`. Useful test state; never an identity for blobs or authority ancestry. |
| Canonical integration commit | The commit on canonical `main` produced by merging a governance change. Unknown until the merge occurs; never predicted or invented. |

A record issued against a decision base becomes active trusted authority only after its own governance change integrates and produces a canonical integration commit.

For a `work/p<phase>-s<slice>-t<ticket>-*` ticket branch or `work/p<phase>-s<slice>-*` slice branch, `scripts/agent-preflight` requires:

1. exactly one tracked governing plan whose `Status` begins with `Accepted`;
2. one matching tracked file under `docs/authorizations/`;
3. `state=authorized`;
4. the exact work ID;
5. the owner who issued authorization, exactly matching `docs/authorizations/TRUSTED-OWNERS` in trusted Repository authority;
6. the exact 40-character base commit reviewed by the owner;
7. the SHA-256 of the accepted governing plan;
8. an RFC 3339 authorization time;
9. bounded scope text; and
10. the record keys in the documented canonical order;
11. valid calendar, clock, and offset values in the RFC 3339 authorization time;
12. non-whitespace owner and scope values;
13. the exact plan and record blobs to be committed unchanged in the explicit implementation commit and to exist unchanged at `refs/remotes/origin/main`;
14. the trusted commit containing that exact pair to be an ancestor of the implementation state; and
15. the recorded base commit to be an ancestor of that trusted authority-source commit.

The canonical remote-tracking ref must be freshly fetched before an authority result is relied on. A normal named local checkout validates its own `HEAD`. Pull-request CI may continue compiling and testing GitHub's synthetic test-merge checkout, but it must set `KILN_IMPLEMENTATION_COMMIT` to the immutable `github.event.pull_request.head.sha`, fetch that exact commit and its required history, and validate authority against that actual implementation head. The supplied value must be an exact 40-character lowercase commit SHA and resolve to the same commit. The synthetic merge commit is never the implementation identity for plan blobs, authorization blobs, or authority-source ancestry.

CI separately fetches canonical `main` into `refs/remotes/origin/main`. An implementation branch cannot create, accept, or authorize its own plan or record: both files must first integrate through the owner-reviewed governance path on canonical `main`, then the actual implementation head must descend from the exact authority-source commit.

`KILN_BRANCH` exists for detached CI checkouts. In a named local checkout, it must exactly match the checked-out branch and cannot reclassify implementation work as planning work.

Planning work under `work/p<phase>-w<work>-*` can create or amend proposed implementation plans without an implementation authorization record. Planning work cannot implement the proposed runtime package.

## Current authority result

- P1-S01 authorization is historical and consumed by its accepted integration at `db02198`.
- P1-S02-T01 adjudication authority was consumed by the exact review of PR #48 at `7ba158bddff76ade9aca79cb8501e675bd0cded9`.
- PR #48 was rejected and closed without merge after exact-state CI run `31294035484`.
- Candidate commit `60367874bfc3c0e6d8cbd736f58e1ae17938943b` remains premature pre-authorization work; the adjudication never rewrote its history.
- P0-W38 corrected and replaced the T01 plan; the corrected plan integrated through PR #56 at `e57678874a36de1700aa666413b51aae31ea9b12`.
- PR #53 is the closed and unmerged historical predecessor; it is not an accepted source.
- P0-W41 records the owner acceptance of the corrected P1-S02-T01 plan against canonical `main` `e57678874a36de1700aa666413b51aae31ea9b12` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`; that acceptance integrated through PR #57 at canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`.
- P0-W42 creates the bounded T01 implementation authorization by adding `docs/authorizations/P1-S02-T01.authorization` against canonical `main` `8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`, binding `work_id=P1-S02-T01`, `state=authorized`, `owner=Joshua Jenks`, `base_sha=8555b81a9b13cb5a424cdf20b17fb4e2b30b43cf`, `plan_sha256=b61f1c611d1a9df65b0334f7c71aa8c723e7d8c0dc4efe9fd5a053a78313e6e5`, `authorized_at=2026-08-10T15:26:00-04:00`, and the bounded T01-v2 scope.
- No P1-S02 runtime implementation exists yet; authorization permits but does not start implementation.
- P0-W43 adjudicates a discovered incompatibility between the accepted T01 plan and the migration runner. The runner splits migration SQL on `;`, which shreds a SQLite trigger body, so migration 0004 could not create the aborting aggregate `evidence_warnings` constraint the plan requires. The owner preserved the Evidence contract and narrowly authorized `lib/kiln/store/migrations.ex` for compound-statement support in `statements/1` only, added P1-S02-T01-R16 and P1-S02-T01-AC15, and reissued the authorization record against amended plan digest `7dfd3b3ad600e67b110ad6eaec12a06880494958027910289250453c6ade662e`, decision base `1243b8f27a594c9440638964a83b56c74774ba28`, and `authorized_at=2026-08-10T23:06:00-04:00`. Amending the plan invalidated the previous `plan_sha256` binding, so the record had to be reissued in the same governance change.
- The amended plan and reissued record are contained in P0-W43 and are not present at the decision base. They become active trusted Repository authority only when P0-W43 integrates on canonical `main`.
- The next legitimate action after P0-W43 integrates is to observe and record the resulting canonical integration commit, move `work/p1-s02-t01-artifact-evidence-substrate-v2` to it, verify blob identity, and begin implementation within the amended authorized surface. That commit is unknown until the merge occurs and must not be predicted. PR #48 must remain closed and unmerged. P1-S02-T02 and later remain unauthorized.

Authorization is effective only while the exact record and accepted plan remain active at trusted canonical `main` and unchanged in the explicit implementation commit. Revocation or supersession requires a governance change that updates or removes the trusted record before further implementation proceeds.
