# P1-S02-T01: Durable Artifact and Evidence substrate

**Document type:** Implementation plan
**Status:** Proposed (corrected replacement plan; owner acceptance and new authorization required)
**Parent slice:** P1-S02
**Branch:** `work/p1-s02-t01-artifact-evidence-substrate-v2` (fresh replacement; rejected branch `work/p1-s02-t01-artifact-evidence-substrate` must not be reused)
**Depends on:** P1-S01-V01 accepted and integrated at `db021984a9278ed582804d0bf3acd74207ad32e9`; corrected plan owner-accepted; new exact T01 authorization integrated on canonical `main`

## Slice contribution

P1-S02 turns the accepted P1-S01 durable foundation into the first complete evidence-backed single-Run change loop. This ticket supplies only the minimum durable Artifact and Evidence substrate that later authorized tickets can use without redefining identity, storage, state binding, result, freshness, completeness, association, or retry semantics.

The ticket contributes prerequisite Evidence to P1-S02-G06, P1-S02-G10, and P1-S02-G16. It cannot satisfy an aggregate gate, evaluate completion, run a Command or Gate, or seal a Receipt by itself.

After merge, Artifact capture and immutable Evidence recording are available through explicit Store APIs. Provider calls, Repository source reads, Patch mutation, Command execution, Gate planning or execution, Findings, criterion aggregation, user acceptance, completion, Receipts, and later P1-S02 behavior remain unreachable.

## Objective

Add a minimal content-addressed Artifact byte store and immutable Evidence record store to the existing `kiln-state/v1` boundary. The implementation must use exact public APIs, one-writer transaction ownership, deterministic canonical records, application and SQLite constraints, idempotent retry semantics, integrity-checked Artifact associations, and protected outcomes that cannot create false passing or dangling Evidence.

## Observed current state

| Observation | Evidence | Collected by | Date or commit |
| --- | --- | --- | --- |
| P1-S01-V01 is owner-accepted and integrated | `docs/work/P1-S01-slice-closeout.md`; PR #46 | Repository authority | `db021984a9278ed582804d0bf3acd74207ad32e9` |
| The Store has direct Exqlite, one writer, `BEGIN IMMEDIATE`, forward checksummed migrations, canonical JSON, idempotency, and no nested transaction contract | ADR 0022; `lib/kiln/store/` | Repository inspection | `f9b5a312` |
| Artifact bytes belong below `$KILN_HOME/artifacts/`; the journal stores bounded references, not byte payloads | `docs/COMMAND-EVIDENCE-AND-ACCEPTANCE.md` section 6 | accepted authority | current `main` |
| First-month Evidence status is `pass | fail | blocked | unknown`; freshness, completeness, and contradiction are separate facts | `docs/COMMAND-EVIDENCE-AND-ACCEPTANCE.md` sections 7 and 8; `Kiln.Conformance.FirstMonth` | accepted authority and conformance | current `main` |
| Generic `kiln-evidence.schema.json` v0 is provisional protocol-neutral conformance scaffolding, not the runtime canonical-byte encoder | README planning authority; `docs/contracts/README.md`; `Kiln.Store.Canonical` | Repository inspection | current `main` |
| PR #48 passed CI but failed technical acceptance on five contract defects | PR #48 at `7ba158bddff76ade9aca79cb8501e675bd0cded9`; CI `31294035484` | owner adjudication | 2026-08-09 |
| PR #48 is closed and unmerged; no T01 runtime path is present on `main` | PR #52; compare to `f9b5a312` | owner adjudication and Repository inspection | 2026-08-09 |

## Applicable decisions and invariants

- ADR 0018: execution stages and Evidence remain exact, current, and non-promotional.
- ADR 0020: prove one single-Run change loop before delegated orchestration.
- ADR 0022: direct Exqlite, one writer, one outer transaction, forward checksummed migrations, and no nested transactions.
- `KILN-INV-006`: Git and the filesystem remain source truth.
- `KILN-INV-007`: completion requires current Evidence.
- `KILN-INV-029`: Claims are not Evidence.
- `KILN-INV-030`: Evidence is immutable and includes method, producer, result, state binding, and freshness rule; Receipts remain distinct.
- `KILN-INV-031`: Artifact existence grants no Evidence, Context, or instruction authority.
- `KILN-INV-042`: Capability results are bounded and provenance-bearing.
- `KILN-INV-051`: current accepted Repository authority outranks rejected or stale planning.
- `KILN-DOM-010` through `KILN-DOM-012`: Claim, Evidence, Receipt, and Artifact inclusion remain distinct; Evidence records are immutable.

No invariant is changed by this plan. Any implementation that requires an invariant change must stop and return to governance with a new or superseding ADR.

## Assumptions and unknowns

### Assumptions

- **P1-S02-T01-A01:** The existing ready Store value can be extended with its accepted state path and derived Artifact root without introducing a second connection owner or process.
- **P1-S02-T01-A02:** A staged same-directory file write followed by digest verification and atomic rename is the smallest credible local Artifact publication path.
- **P1-S02-T01-A03:** A promoted content blob with no committed metadata row is an unreachable orphan, not a durable Artifact record. It may be reused by a later exact-content write but is not automatically deleted in the first month.
- **P1-S02-T01-A04:** Criterion aggregation and mutable currentness projections belong to later tickets; T01 persists immutable observations and provides deterministic protected classification without claiming completion authority.

### Unknowns

- **P1-S02-T01-U01:** Exact filesystem performance and interruption windows on OD-02 remain unknown until an authorized implementation exercises the owner-machine diagnostic.
- **P1-S02-T01-U02:** Long-term Artifact garbage collection and retention expiry remain deferred. T01 performs no automatic deletion or compaction.
- **P1-S02-T01-U03:** Later Quality Compiler concepts may add association tables or projections. They must consume this immutable substrate rather than mutate T01 Evidence records.

## Domain contract

### Artifact identity and bytes

An Artifact record and its content blob have distinct identities:

- `artifact_id` is an opaque Kiln UUIDv7 for one provenance-bearing record;
- `content_digest` is `sha256:` plus 64 lowercase hexadecimal characters over the exact stored bytes;
- identical content may share one content-addressed blob while separate Artifact records preserve different owners, producers, bindings, sensitivity, or retention;
- Artifact bytes live below `$KILN_HOME/artifacts/sha256/<first-two-hex>/<remaining-hex>` and never in the SQLite journal or `artifacts` table;
- a relative content location is stored; an absolute path supplied by a caller is rejected;
- Artifact existence does not make the bytes Evidence, model Context, or instruction authority.

The immutable Artifact record contains:

```text
artifact_id
owner_kind: project | session | run
owner_id
producer_kind: command | provider | pack | patch | repository | user | deterministic_service
producer_id
kind: input | output | report | log | snapshot | patch | diff | summary | other
media_type
encoding: binary | utf_8 | utf_8_bom
content_digest
byte_size
content_location
repository_state_digest | null
trust: kiln_generated | registered_command_output | provider_output | user_supplied | repository_observation
sensitivity: public | project | sensitive | secret | unknown
retention_class: run | session | project | audit | release | policy_controlled
recorded_at
schema: kiln.artifact/v1
idempotency_key
request_digest
```

`content_digest`, immutable metadata, and the schema identifier form the canonical `request_digest`. `recorded_at` is caller-supplied as part of the request, so an exact retry is byte-for-byte classifiable.

### Evidence result and immutable record

T01 implements first-month criterion Evidence. Its required `result` field is exactly:

```text
pass | fail | blocked | unknown
```

This vocabulary is the current first-month Evidence authority in `docs/COMMAND-EVIDENCE-AND-ACCEPTANCE.md` and `Kiln.Conformance.FirstMonth`. It is not the generic v0 Claim relation vocabulary `supports | refutes | inconclusive | records_fact`. Claim relations remain a separate later association and cannot substitute for the T01 result.

An immutable Evidence record contains:

```text
evidence_id
criterion_id
criterion_revision
subject_id
subject_kind: session | run | operation | patch | command | artifact | evidence | repository
subject_state_digest
producer_kind: command | provider | pack | patch | repository | user | deterministic_service
producer_id
method: registered_command | repository_observation | deterministic_validator | user_observation
result: pass | fail | blocked | unknown
artifact_id | null
observation_digest
completeness: complete | partial | truncated | missing | unknown
freshness_rule
freshness_ttl_seconds | null
observed_at
recorded_at
warnings
rationale
schema: kiln.evidence/v1
idempotency_key
request_digest
record_digest
```

`evidence_id` is an opaque caller-supplied Kiln UUIDv7 in the typed record request. `record_digest` is the schema-bound SHA-256 of the complete immutable Evidence payload, excluding only `evidence_id`, `idempotency_key`, `request_digest`, and `record_digest`. `request_digest` binds the exact record request, including the caller-supplied identifiers and time fields.

`Kiln.Store.Canonical.encode/1` is the runtime canonical-byte authority. `priv/schemas/kiln.artifact/v1.json` and `priv/schemas/kiln.evidence/v1.json` describe and validate record shape; they do not define byte ordering or replace the canonical encoder. The provisional protocol-neutral v0 contract remains historical conformance scaffolding for broader domain mapping.

### Freshness and TTL

`freshness_rule` is exactly one of:

```text
same_repository_state
same_patch_and_repository_state
same_command_registration_and_repository_state
manual_same_repository_state
time_bound
```

Rules:

- `time_bound` requires `freshness_ttl_seconds` to be an integer from 1 through 2,147,483,647;
- every non-time rule requires `freshness_ttl_seconds` to be `NULL`;
- zero, negative, fractional, textual, or overflowed TTL values are invalid;
- a TTL never makes Evidence current by itself; currentness also requires every non-time state binding named by the rule to match;
- expiration is derived from `observed_at + ttl` using an injected observation time in tests, never an ambient sleep;
- Evidence is never updated from current to stale. A later evaluation derives stale currentness while retaining the immutable historical record.

The application validator and the `evidence_records` table enforce the same rule/TTL matrix. Direct SQL inserts that bypass Elixir validation must fail with a SQLite constraint error and leave no row.

### Artifact association

`artifact_id` is nullable because deterministic Repository or user observations can be complete without a retained byte Artifact. When present:

- SQLite foreign keys require an existing Artifact metadata row;
- `registered_command` Evidence requires a non-null Artifact;
- before Evidence insertion, T01 reopens the relative Artifact path below the accepted root, rehashes the bytes, and compares size and digest to metadata;
- a missing, path-escaping, special, unreadable, size-mismatched, or digest-mismatched Artifact produces protected `integrity` and no Evidence row;
- an existing Artifact record remains a valid independent record when a later Evidence attempt fails. Artifact and Evidence are distinct domain facts, so this is not partial Evidence persistence.

### Public APIs and ownership

The Artifact write API is authoritatively:

```elixir
Kiln.Artifact.Store.put(ready_store, %Kiln.Artifact.PutRequest{})
```

It is exactly `put/2`. The first argument is the ready Store value returned by `Kiln.Store.start/1`, extended with the accepted state path and derived Artifact root. The second argument contains the bytes, immutable metadata, caller-supplied UUIDv7 `artifact_id`, idempotency key, and recorded time. No public `put/3` exists.

The Evidence APIs are:

```elixir
Kiln.Evidence.new(attrs)
Kiln.Evidence.Store.record(ready_store, %Kiln.Evidence.RecordRequest{})
```

`new/1` is pure construction and validation. `record/2` owns the durable Evidence write and receives the expected current subject-state digest and injected evaluation time in its typed request. No Gate, Command, or later application context owns T01 persistence implicitly.

Artifact publication owns filesystem staging and one outer SQLite metadata transaction. Evidence recording owns one outer `BEGIN IMMEDIATE` transaction. Neither API opens a nested transaction, calls the other write API, or accepts a caller callback as transaction logic.

### Idempotency

Both tables have a unique `idempotency_key` and stored `request_digest`:

- an unseen key performs one write;
- the same key and same request digest returns the previously committed record with `status: replayed` and writes nothing;
- the same key and a different request digest returns a typed `:idempotency_conflict` protected as `integrity` and writes nothing;
- matching content digest alone is not a replay key and does not collapse distinct Artifact provenance records;
- matching Evidence record digest under a different idempotency key may create a separate immutable observation because producer, time, or workflow intent can differ.

### Protected classifications

Protected classifications are deterministic outcomes, not values a caller may claim.

| Classification | Exact semantics | Durable behavior | Failure or return behavior |
| --- | --- | --- | --- |
| `contradiction` | A newly valid, complete, current `pass` or `fail` Evidence record conflicts with an existing valid, complete, current record for the same criterion revision and subject-state binding | Preserve both immutable Evidence rows in one committed transaction; return their IDs as the contradicting set; no aggregate pass is created | `record/2` returns committed Evidence with `classification: contradiction`; later criterion evaluation must remain contradicted |
| `stale` | The proposed record's subject-state binding does not match the expected current binding, or an existing record no longer matches the evaluated state | Reject a newly stale write with no Evidence row; retain already recorded historical Evidence unchanged | return protected `stale`; re-observation or re-execution is required |
| `incomplete` | Required observation content is partial, truncated, missing, or unknown | A non-passing `blocked` or `unknown` record may commit truthfully with its completeness; `pass` with non-complete content is rejected and writes no row | return committed `incomplete` for truthful non-pass, or protected rejection for a false pass |
| `integrity` | Canonical digest mismatch, Artifact absence/corruption/path escape, foreign-key failure, impossible stored replay, ID collision, or idempotency-key reuse with a different request | Roll back the entire Evidence transaction; never create or update an Evidence row | return typed Store integrity or idempotency error with `classification: integrity` |

`blocked` and `unknown` are Evidence results. `stale`, `contradiction`, `incomplete`, and `integrity` describe current applicability or protection. They must not be normalized into one another or into `pass`.

### Failure atomicity

Artifact publication proceeds in this order:

1. validate request, root, vocabulary, byte limit, UUID, time, and idempotency shape;
2. compute canonical request and content digests;
3. open one `BEGIN IMMEDIATE` transaction and classify idempotency;
4. return an integrity-verified replay, or reject a conflict, before any new blob write;
5. for a new request, write bytes to a same-directory temporary file, sync, close, reopen, and verify size and digest;
6. atomically rename into the content-addressed final path or verify the already-existing identical blob;
7. insert exactly one Artifact metadata row and commit only after the final blob is reverified.

No committed Artifact row may reference missing or mismatched bytes. A crash after content promotion but before metadata commit may leave only an unreachable digest-addressed blob. It creates no Artifact identity, grants no authority, and may be reused by a later matching write. T01 does not delete it automatically.

Evidence recording validates and verifies its Artifact association, then performs idempotency classification, current-state precondition, insertion, and contradiction classification inside one `BEGIN IMMEDIATE` transaction. A fault at any point rolls back the new Evidence row and leaves prior Artifact and Evidence records unchanged.

## Requirements

- **P1-S02-T01-R01:** The Store shall expose an Artifact root below the accepted `$KILN_HOME` and shall never store Artifact content bytes in SQLite.
- **P1-S02-T01-R02:** The system shall persist provenance-bearing Artifact metadata separately from content identity, using UUIDv7 `artifact_id` and SHA-256 `content_digest`.
- **P1-S02-T01-R03:** `Kiln.Artifact.Store.put/2` shall accept exactly a ready Store and one typed request; no public `put/3` shall exist.
- **P1-S02-T01-R04:** Artifact publication shall use staged, synced, digest-verified, same-directory atomic placement before committing metadata that references the blob.
- **P1-S02-T01-R05:** Evidence shall carry required `result: pass | fail | blocked | unknown`, method, producer, exact subject-state binding, completeness, and freshness rule.
- **P1-S02-T01-R06:** `Kiln.Evidence.Store.record/2` shall own the durable Evidence path and one outer immediate transaction; no later Gate path shall be the implicit persistence owner.
- **P1-S02-T01-R07:** The runtime shall use `Kiln.Store.Canonical.encode/1` and schema-bound digests as byte authority; runtime JSON Schemas shall remain shape validators.
- **P1-S02-T01-R08:** Application validation and SQLite shall enforce the same bounded vocabularies, digest shapes, result/completeness safety, Artifact foreign keys, and exact freshness rule/TTL matrix.
- **P1-S02-T01-R09:** Time-bound freshness shall require an integer TTL from 1 through 2,147,483,647; non-time rules shall require `NULL`; invalid direct writes shall roll back deterministically.
- **P1-S02-T01-R10:** Contradiction, stale, incomplete, and integrity outcomes shall follow the protected-classification table and shall never create a false pass, dangling Evidence association, or partially committed Evidence row.
- **P1-S02-T01-R11:** Exact retries shall replay by idempotency key and request digest; conflicting reuse shall return integrity-classified idempotency failure and write nothing.
- **P1-S02-T01-R12:** Migrations 0003 and 0004 shall be forward-only, checksummed, atomic per migration, compatible with fresh and upgraded v1 stores, and shall not change `kiln-state/v1`.
- **P1-S02-T01-R13:** Artifact and Evidence shall remain plain data and functions; no process, registry, pool, retry loop, savepoint, nested transaction, provider, Repository source access, Patch, Command, Gate, completion, or Receipt surface shall be added.
- **P1-S02-T01-R14:** Secrets, denied paths, raw transcript, and Repository source content shall not enter metadata or ordinary errors; Artifact sensitivity and retention shall remain explicit.

## Security boundary

Allowed:

- extend the ready Store value with the accepted state path and derived Artifact root;
- add pure Artifact and Evidence data, validators, canonical-record builders, and Store functions;
- add migrations 0003 and 0004 with database constraints and indexes justified by exact lookup or idempotency needs;
- add descriptive runtime JSON Schemas;
- add deterministic temporary-root and SQLite fixtures;
- use existing Store error classes with domain-specific codes.

Denied:

- arbitrary or caller-selected Artifact roots;
- absolute, escaping, symlinked, or special-file Artifact locations;
- Artifact bytes in SQLite;
- new Store error classes when existing `integrity`, `idempotency_conflict`, `precondition`, `io`, and `unknown` classes suffice;
- caller-supplied transaction callbacks, nested transactions, savepoints, hidden retry, or automatic deletion;
- provider, Repository source read, Context, Tool, Patch, Approval, Command, Gate, Finding, Assurance, criterion aggregation, completion, Receipt, release, Child, TUI, protocol, or Wave B behavior;
- treating schema files, model output, Artifact existence, or a successful write as acceptance authority.

Any unclassified filesystem or database effect returns `unknown` or integrity failure and blocks the operation. Errors must be bounded and must not disclose Artifact bytes, secrets, absolute denied paths, connection handles, or raw database exceptions.

## Proposed changes

1. Add Artifact record, put-request, and Store modules with exact `put/2`, content-addressed filesystem placement, metadata persistence, integrity verification, and idempotent replay.
2. Add Evidence record, record-request, validation, and Store modules with explicit result, durable `record/2`, exact state precondition, Artifact verification, protected classification, and idempotency.
3. Extend the ready Store value with its state path and a derived Artifact root below the same accepted Kiln home.
4. Add `0003_artifacts.sql` for provenance metadata and `0004_evidence_records.sql` for immutable Evidence, foreign keys, direct-write constraints, and bounded indexes.
5. Add `kiln.artifact/v1` and `kiln.evidence/v1` runtime Schemas as descriptive shape validation, with canonical bytes owned only by `Kiln.Store.Canonical`.
6. Add deterministic tests for byte placement, record identity, association integrity, transaction rollback, direct-SQL constraints, restart, idempotency, and every protected classification.
7. Extend the existing Store migration and owner-machine diagnostic tests without changing the store-format identifier.

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `lib/kiln/store.ex` | ready Store path and derived Artifact-root data | Proposed |
| `lib/kiln/artifact.ex` | immutable Artifact record | Proposed |
| `lib/kiln/artifact/put_request.ex` | exact typed `put/2` request | Proposed |
| `lib/kiln/artifact/store.ex` | filesystem publication, metadata, integrity, idempotency | Proposed |
| `lib/kiln/evidence.ex` | immutable Evidence and pure `new/1` validation | Proposed |
| `lib/kiln/evidence/record_request.ex` | expected state and injected evaluation time | Proposed |
| `lib/kiln/evidence/store.ex` | durable `record/2`, association checks, protected classification | Proposed |
| `priv/store/migrations/0003_artifacts.sql` | Artifact metadata and idempotency constraints | Proposed |
| `priv/store/migrations/0004_evidence_records.sql` | Evidence, result, association, vocabulary, TTL, and idempotency constraints | Proposed |
| `priv/schemas/kiln.artifact/v1.json` | descriptive Artifact v1 shape | Proposed |
| `priv/schemas/kiln.evidence/v1.json` | descriptive Evidence v1 shape | Proposed |
| `test/kiln/artifact/` | publication, integrity, replay, and failure fixtures | Proposed |
| `test/kiln/evidence/` | construction, persistence, classification, and rollback fixtures | Proposed |
| `test/kiln/store/migrations_test.exs` | fresh, upgrade, direct-write, failed-migration, and replay coverage | Proposed |
| `test/kiln/store_test.exs` | ready Store Artifact-root and restart coverage | Proposed |
| `scripts/diagnostics/p1-s01-store-host` | additive 0003/0004 owner-machine observations | Proposed only if the existing diagnostic requires it |

No other path is authorized. Discovery that another path is necessary requires plan adjudication before implementation continues.

## Migration and rollback contract

Migration `0003_artifacts.sql` creates metadata only. It includes:

- primary key on UUIDv7 `artifact_id`;
- unique `idempotency_key` and stored `request_digest`;
- bounded `CHECK` constraints for every vocabulary;
- digest, byte-size, relative-location, and non-empty owner/producer constraints;
- indexes only for idempotency, content digest, owner, and producer lookups exercised by T01 tests.

Migration `0004_evidence_records.sql` includes:

- primary key on UUIDv7 `evidence_id`;
- unique `idempotency_key` and stored request and record digests;
- foreign key to `artifacts.artifact_id`;
- bounded `CHECK` constraints for result, method, completeness, freshness rule, digests, and required non-empty fields;
- `registered_command` requires an Artifact reference;
- `result = 'pass'` requires `completeness = 'complete'`;
- `time_bound` requires integer `freshness_ttl_seconds` from 1 through 2,147,483,647 and every other freshness rule requires `NULL`;
- indexes only for idempotency, criterion/revision/subject binding, Artifact reference, and producer queries exercised by T01.

Each migration runs in the existing migration runner's own immediate transaction. Any statement or constraint failure rolls back the whole migration and does not write its schema-migration checksum. Migrations 0001 and 0002 are immutable. There is no down migration and no automatic repair, deletion, or schema-format bump. Upgrade fixtures must prove an existing valid version-2 store remains readable and replays before and after 0003/0004.

## Acceptance criteria

- **P1-S02-T01-AC01 — Fresh and upgraded migration**
  - **Given** a fresh Store and a valid store upgraded through migration 0002;
  - **When** startup applies migrations 0003 and 0004;
  - **Then** each migration applies once with stored checksum, accepted pragmas remain verified, `kiln-state/v1` remains unchanged, restart is clean, and a faulted migration leaves neither its table nor checksum.
  - **Evidence:** migration tests, schema introspection, restart tests, and owner-machine diagnostic.
- **P1-S02-T01-AC02 — Artifact content and record identity**
  - **Given** identical bytes with identical and different provenance requests;
  - **When** `Artifact.Store.put/2` records them;
  - **Then** content digests and blob location match, exact retry replays one record, different provenance can create a distinct UUIDv7 record sharing the blob, and no content bytes exist in SQLite.
  - **Evidence:** filesystem, SQL, digest, identity, and replay fixtures.
- **P1-S02-T01-AC03 — Atomic Artifact publication**
  - **Given** staged-write, sync, rename, digest, metadata, and injected-fault cases;
  - **When** publication fails at each boundary;
  - **Then** no committed Artifact row references missing or mismatched bytes, existing blobs are not corrupted, and a pre-metadata orphan grants no Artifact identity or authority.
  - **Evidence:** protected fault matrix and restart inspection.
- **P1-S02-T01-AC04 — Exact Artifact API**
  - **Given** compiled public exports and call sites;
  - **When** API conformance is inspected;
  - **Then** Artifact persistence exposes `put/2` with `(ready_store, PutRequest)` and exposes no `put/3`.
  - **Evidence:** export and compile-time contract tests.
- **P1-S02-T01-AC05 — Evidence result and durable path**
  - **Given** each accepted result and method;
  - **When** `Evidence.new/1` and `Evidence.Store.record/2` run;
  - **Then** the immutable record carries `pass | fail | blocked | unknown`, canonical record digest, producer, exact state binding, completeness, freshness rule, and a committed Evidence row that survives restart.
  - **Evidence:** vocabulary, canonical digest, persistence, and restart tests.
- **P1-S02-T01-AC06 — TTL boundary**
  - **Given** every freshness rule with nil, zero, negative, positive-integer, fractional, and textual TTL variants;
  - **When** each is attempted through Elixir and direct SQL;
  - **Then** only positive integer TTL for `time_bound` and `NULL` for non-time rules can commit; every invalid case leaves zero rows.
  - **Evidence:** application matrix, direct-SQL constraint matrix, and row-count proof.
- **P1-S02-T01-AC07 — Idempotency and collision**
  - **Given** exact retries and same-key/different-request attempts for Artifact and Evidence;
  - **When** persistence runs concurrently or sequentially through the one writer;
  - **Then** exact retry returns the original record without a second row, conflicting reuse returns integrity-classified idempotency failure, and no existing row changes.
  - **Evidence:** retry, conflict, row-count, and immutable-row fixtures.
- **P1-S02-T01-AC08 — Contradiction**
  - **Given** current complete `pass` and `fail` Evidence for the same criterion revision and subject binding;
  - **When** the second valid observation records;
  - **Then** both immutable observations commit, the return is classified `contradiction` with both IDs, and no passing aggregate or mutable overwrite is created.
  - **Evidence:** contradiction transaction and restart fixture.
- **P1-S02-T01-AC09 — Stale binding**
  - **Given** a proposed Evidence record whose subject binding differs from the expected current binding;
  - **When** `record/2` runs;
  - **Then** it returns protected `stale`, writes no row, and leaves existing historical Evidence unchanged; re-evaluating an old row against a new state reports stale without mutation.
  - **Evidence:** stale-write and historical-currentness fixtures.
- **P1-S02-T01-AC10 — Incomplete proof**
  - **Given** partial, truncated, missing, or unknown observation content;
  - **When** a non-passing or passing Evidence result is attempted;
  - **Then** truthful `blocked` or `unknown` Evidence may commit as `incomplete`, while `pass` is rejected with no row.
  - **Evidence:** completeness/result cross-product and row-count fixtures.
- **P1-S02-T01-AC11 — Integrity and association**
  - **Given** missing, corrupt, size-mismatched, path-escaping, special-file, or foreign-key-invalid Artifact associations and record-digest faults;
  - **When** Evidence persistence runs;
  - **Then** it returns protected `integrity`, rolls back the whole Evidence transaction, and creates no dangling Evidence row.
  - **Evidence:** Artifact-integrity and direct-SQL foreign-key fixtures.
- **P1-S02-T01-AC12 — Transaction and scope boundary**
  - **Given** the implementation call graph and fault injection;
  - **When** reviewed and tested;
  - **Then** each write has one explicit outer transaction owner, nested use is rejected, no process exists for Artifact or Evidence, and no denied later capability is reachable.
  - **Evidence:** transaction-call inspection, nested-use test, dependency scan, and runtime-path review.
- **P1-S02-T01-AC13 — Exact-state package gate**
  - **Given** the exact replacement implementation head;
  - **When** the complete Repository and owner-machine validation runs;
  - **Then** all checks pass and completion Evidence binds only that head.
  - **Evidence:** exact-head CI, OD-02 diagnostic, final diff, and recorded digest.

## Deterministic verification

```bash
scripts/agent-preflight
scripts/test-agent-preflight
python3 scripts/validate_first_month_contracts.py
python3 scripts/validate_json_schema_contracts.py
scripts/validate-agent-assets
mix format --check-formatted
mix compile --warnings-as-errors
mix xref graph --format cycles --label compile-connected --fail-above 0
mix test test/kiln/artifact test/kiln/evidence test/kiln/store
mix test
scripts/diagnostics/p1-s01-store-host
```

Every command must exit `0`. Tests must use deterministic temporary roots, injected times, and injected faults. They must not sleep, use a live provider, access a public network, depend on an external protocol server, or write outside their fixture root.

Owner-machine verification must record the exact implementation head, host profile, filesystem, Exqlite, SQLite, migration checksums, Artifact root, restart result, and protected fault matrix. It must confirm `store_format = kiln-state/v1` and preserve P1-S01 observations.

## Demo contribution

```text
P1-S02-D01 prerequisite: publish one deterministic Artifact through put/2, record one result-bearing Evidence item bound to that Artifact and exact subject state, restart, replay both exact idempotency keys, and inspect the same immutable records without running a provider, Command, Gate, or completion evaluator.
```

## Required completion Evidence

| Evidence ID | Acceptance criterion | Required Evidence |
| --- | --- | --- |
| P1-S02-T01-E01 | AC01 | fresh/upgrade/fault migration and restart results |
| P1-S02-T01-E02 | AC02 | content digest, blob sharing, UUID identity, SQL-no-bytes, and replay results |
| P1-S02-T01-E03 | AC03 | staged publication fault matrix and no-dangling-row proof |
| P1-S02-T01-E04 | AC04 | exact `put/2` export and no-`put/3` proof |
| P1-S02-T01-E05 | AC05 | result vocabulary, canonical digest, persistence, and restart results |
| P1-S02-T01-E06 | AC06 | application and direct-SQL TTL matrix |
| P1-S02-T01-E07 | AC07 | exact replay, conflict, concurrency, and immutable-row results |
| P1-S02-T01-E08 | AC08 | contradiction commit and classification results |
| P1-S02-T01-E09 | AC09 | stale rejection and historical-currentness results |
| P1-S02-T01-E10 | AC10 | completeness/result cross-product results |
| P1-S02-T01-E11 | AC11 | Artifact-integrity, foreign-key, rollback, and zero-row results |
| P1-S02-T01-E12 | AC12 | transaction call graph, nested-use, dependency, and denied-surface review |
| P1-S02-T01-E13 | AC13 | exact-head CI, owner-machine diagnostic, final diff, and plan digest binding |

### Slice gate contribution

| Slice gate | Contribution |
| --- | --- |
| P1-S02-G06 | Prerequisite only: immutable Evidence distinguishes result from Claim and binds exact subject state |
| P1-S02-G10 | Prerequisite only: result, freshness, completeness, contradiction, and integrity remain non-promotional; later criterion aggregation must prove completion behavior |
| P1-S02-G16 | Prerequisite only: Kiln-owned Artifact publication, integrity verification, raw-byte retention, and Evidence association; later Command and Gate execution must prove the aggregate gate |

T01 does not update or satisfy the aggregate P1-S02 verification manifest.

## Explicit exclusions

- No reuse, cherry-pick, restoration, or continuation of rejected PR #48 code or branch.
- No provider or fake-provider execution.
- No Repository source read or mutation.
- No Context, Tool, Patch, Approval, Command, process-group helper, Gate execution, Finding, Assurance, criterion evaluation, aggregate completion, user acceptance, product Receipt, release, Child, TUI, protocol, or Wave B behavior.
- No Artifact deletion, compaction, remote backend, generalized object store, ORM, pool expansion, nested transaction, savepoint, hidden retry, or automatic corrupt-store repair.
- No claim that a stored Artifact or Evidence row completes a criterion, Task, Run, Session, slice, or product stage.

## Completion record

**Result:** Proposed corrected replacement plan; not owner-accepted, authorized, implemented, verified, or accepted.

### Rejected-plan history

- PR #48 candidate commit `60367874bfc3c0e6d8cbd736f58e1ae17938943b` was premature.
- The correctly authorized adjudication head was `7ba158bddff76ade9aca79cb8501e675bd0cded9`.
- Exact-state CI run `31294035484` passed Repository checks.
- Technical adjudication rejected the candidate for missing Evidence result, missing Evidence persistence ownership, false protected-classification claims, inadequate TTL database constraints, and `put/2` versus `put/3` disagreement.
- PR #48 closed without merge. No runtime code from it entered `main`.
- P0-W37 removed the consumed authorization and integrated through PR #52 at `f9b5a312ac31ee4015025a87bcd3cec199b12297`.

The corrected plan preserves that negative Evidence. It does not retroactively authorize, accept, or rehabilitate any rejected implementation state.

### Current acceptance status

| Stage | Status | Result |
| --- | --- | --- |
| Corrected planning | Proposed | ready for owner adjudication after P0-W38 integration |
| Owner acceptance | Not granted | a separate owner decision is required |
| Implementation authorization | Not granted | no active authorization record exists |
| Replacement implementation | Not started | a fresh branch and package are required after authorization |
| Verification | Not run | only a later exact replacement head can supply runtime Evidence |
| Acceptance | Not granted | implementation and exact completion Evidence do not exist |

### Required next action

After P0-W38 merges, the owner must accept, revise, or reject this corrected plan. Acceptance alone does not authorize implementation. A later governance action must record the exact accepted plan digest, reviewed base SHA, owner, time, and bounded scope in a new T01 authorization on canonical `main`. Only then may a fresh replacement implementation branch begin; PR #48 must remain closed and unmerged.
