# P1-S02-T01: Durable Artifact and Evidence substrate

**Document type:** Implementation plan
**Status:** Accepted (corrected replacement plan; owner acceptance recorded; amended by P0-W43 for P1-S02-T01-R16; bounded implementation authorization active)
**Parent slice:** P1-S02
**Branch:** `work/p1-s02-t01-artifact-evidence-substrate-v2` (fresh replacement; rejected branch `work/p1-s02-t01-artifact-evidence-substrate` must not be reused)
**Depends on:** P1-S01-V01 accepted and integrated at `db021984a9278ed582804d0bf3acd74207ad32e9`; corrected plan owner-accepted against canonical `main` `e57678874a36de1700aa666413b51aae31ea9b12` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`; new exact T01 authorization integrated on canonical `main`

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
| The Store has direct Exqlite, one writer, `BEGIN IMMEDIATE`, forward checksummed migrations, canonical JSON, idempotency, and no nested transaction contract | ADR 0022; `lib/kiln/store/` | Repository inspection | `9f09ea2400ea73257c1fb2efc566ee165a4a1181` (current canonical main; pre-P0-W39 base `f9b5a312ac31ee4015025a87bcd3cec199b12297` was the historical snapshot) |
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
- `KILN-INV-051`: Documentation resolves by authority and version. For Elixir Projects, Kiln MUST prefer active Repository documentation, accepted ADRs and specifications, dependency-authored rules, exact local ExDoc, and running-Project documentation before Context7, official external sources, general web research, or model memory.
- `KILN-DOM-010` through `KILN-DOM-012`: Claim, Evidence, Receipt, and Artifact inclusion remain distinct; Evidence records are immutable.

No invariant is changed by this plan. Any implementation that requires an invariant change must stop and return to governance with a new or superseding ADR.

## Assumptions and unknowns

### Assumptions

- **P1-S02-T01-A01:** The existing ready Store value can be extended with its accepted state path and derived Artifact root without introducing a second connection owner or process.
- **P1-S02-T01-A02:** A staged same-directory file write followed by digest verification and atomic rename is the smallest credible local Artifact publication path.
- **P1-S02-T01-A03:** A promoted content blob with no committed metadata row is an unreachable orphan, not a durable Artifact record. It may be reused by a later exact-content write but is not automatically deleted in the first month.
- **P1-S02-T01-A04:** Criterion aggregation and durable or mutable currentness projections belong to later tickets; T01 persists immutable observations and provides a pure ephemeral Evidence view without claiming completion authority.

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
session_id
run_id
creator_operation_id | null
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
host_profile_digest | null
trust: kiln_generated | registered_command_output | provider_output | user_supplied | repository_observation
sensitivity: public | project | sensitive | secret | unknown
retention_class: run | session | project | audit | release | policy_controlled
completeness: complete | partial | truncated | missing | unknown
recorded_at
schema: kiln.artifact/v1
idempotency_key
request_digest
```

`content_digest`, immutable metadata, and the schema identifier form the canonical `request_digest`. `recorded_at` is caller-supplied as part of the request, so an exact retry is byte-for-byte classifiable.

This record preserves P0-W24's Artifact contract: `schema` maps to `artifact_schema`, `byte_size` to `byte_count`, `content_location` to `storage_path`, and `recorded_at` to `created_at`; Session, Run, creator operation, Repository, host, sensitivity, trust, and completeness bindings are explicit. Current `integrity_status` is derived by an integrity-checked read and is never written back into immutable metadata.

### Required bounds and overflow behavior

T01 fixes the following limits. Every length is measured over UTF-8 bytes, not code points.

| Value | Maximum |
| --- | ---: |
| one Artifact content blob | 16,777,216 bytes |
| canonical Artifact metadata request | 65,536 bytes |
| canonical Evidence record request | 65,536 bytes |
| `criterion_id`, `subject_id`, `producer_id`, or `command_result_id` | 256 bytes each |
| `criterion_revision` | 64 bytes |
| `media_type` | 255 bytes |
| `idempotency_key` | 256 bytes |
| `rationale` | 8,192 bytes |
| warnings | 64 items, 1,024 bytes per item, 16,384 bytes aggregate |
| Artifact references on one Evidence record | 32 unique IDs |
| candidate records in one currentness evaluation | 256 |
| derived relative content location | 128 ASCII bytes |

UUIDv7 identifiers are canonical lowercase 36-character UUID strings. Digests retain their exact algorithm-prefixed shapes. Identifiers, media type, idempotency keys, warnings, and rationale reject NUL and disallowed control bytes; empty values are allowed only where the field is explicitly nullable.

Overflow is never truncated by an Artifact or Evidence API. Application validation returns Store class `precondition` with domain code `limit_exceeded` before filesystem staging or a database transaction, and writes nothing. Direct SQLite paths enforce the persisted byte-size, scalar-length, warning-position and warning-length, and Artifact-reference-position bounds with `CHECK` constraints or aborting triggers. A direct overflow aborts the statement or outer transaction. Output capture owned by later Command work may deliberately produce `completeness: truncated` before calling T01, but that is an explicit observation result rather than silent T01 truncation.

### Evidence result and immutable record

T01 implements first-month criterion Evidence. Its required `result` field is exactly:

```text
pass | fail | blocked | unknown
```

This vocabulary is the current first-month Evidence authority in `docs/COMMAND-EVIDENCE-AND-ACCEPTANCE.md` and `Kiln.Conformance.FirstMonth`. It is not the generic v0 Claim relation vocabulary `supports | refutes | inconclusive | records_fact`. Claim relations remain a separate later association and cannot substitute for the T01 result.

The immutable persisted Evidence record contains:

```text
evidence_id
session_id
run_id
criterion_id
criterion_revision
subject_id
subject_kind: session | run | operation | patch | command | artifact | evidence | repository
subject_state_digest
producer_kind: command | provider | pack | patch | repository | user | deterministic_service
producer_id
method: registered_command | repository_observation | deterministic_validator | user_observation
result: pass | fail | blocked | unknown
repository_state_digest
patch_id | null
patch_digest | null
patch_result_digest | null
host_profile_digest | null
command_registration_digest | null
command_result_id | null
artifact_ids
evaluator_digest
observation_digest
completeness: complete | partial | truncated | missing | unknown
freshness_rule
observed_at
recorded_at
warnings
rationale
schema: kiln.evidence/v1
idempotency_key
request_digest
record_digest
```

`evidence_id` is an opaque caller-supplied Kiln UUIDv7 in the typed record request. `artifact_ids` is a unique set represented in canonical bytes as ascending lowercase UUID strings. SQLite stores the association in `evidence_artifacts`, not as a singular foreign-key column or caller-ordered JSON. `record_digest` is the schema-bound SHA-256 of the complete immutable Evidence payload, excluding only `evidence_id`, `idempotency_key`, `request_digest`, and `record_digest`. `request_digest` binds the exact persistent record request, including the caller-supplied identifiers and time fields, but excludes the separate admission and currentness contexts.

The tuple `subject_kind`, `subject_id`, and `subject_state_digest` is the exact canonical representation of P0-W24's `subject`. `patch_id`, `patch_digest`, and `patch_result_digest` preserve the accepted Patch result and digest binding. `host_profile_digest` is the first-month host/environment fingerprint binding. `command_registration_digest` and `command_result_id` preserve the Command registration and Command-result bindings. `artifact_ids` is the canonical plural representation of P0-W24's `artifact_references`. `evaluator_digest` binds the exact deterministic evaluator or accepted manual-observation contract. Registered-Command Evidence requires non-null Command registration, Command result, and host-profile bindings; Repository Evidence may leave Command fields null. Every nullable field has an explicit canonical `null` representation.

`Kiln.Store.Canonical.encode/1` is the runtime canonical-byte authority. `priv/schemas/kiln.artifact/v1.json` and `priv/schemas/kiln.evidence/v1.json` describe and validate record shape; they do not define byte ordering or replace the canonical encoder. The provisional protocol-neutral v0 contract remains historical conformance scaffolding for broader domain mapping.

T01 does not supersede P0-W24 or the active `kiln-first-month` conformance Schema. It refines their storage and projection boundary. The canonical first-month Evidence item is an `EvidenceView` composed from the immutable record plus a pure currentness result:

```text
status          := evidence_record.result
subject         := {subject_kind, subject_id, subject_state_digest}
repository_state_digest := evidence_record.repository_state_digest
patch_binding          := {patch_id, patch_digest, patch_result_digest}
host_profile_digest      := evidence_record.host_profile_digest
command_result_id        := evidence_record.command_result_id
artifact_references      := evidence_record.artifact_ids
freshness                := currentness.freshness
contradiction            := currentness.contradiction
invalidated_at           := currentness.invalidated_at
```

The active conformance projection emits exactly `kind`, `evidence_id`, `criterion_id`, `status`, `freshness`, `completeness`, `contradiction`, `repository_state_digest`, and `record_digest`; it maps stored `result` to `status`. Projection cannot change the stored record or promote its result.

The immutable applicability binding is the canonical digest of criterion ID and revision, subject tuple, Repository state, nullable Patch identity/digest/result, nullable host profile, nullable Command registration and result, sorted Artifact IDs, evaluator digest, and freshness rule. Currentness compares every non-null binding and verifies every Artifact integrity input. The rule then adds its specific requirement: Patch identity/digest/result matching for `same_patch_and_repository_state`, Command-registration and result matching for `same_command_registration_and_repository_state`, and absence of explicit invalidation for `manual_same_repository_state`.

Contradiction grouping is intentionally broader than applicability identity. After each candidate is independently proved current and complete, incompatible `pass` and `fail` results contradict when criterion ID and revision, subject tuple, Repository state, and nullable Patch identity/digest/result match. Producer, method, Command result, Artifact set, and evaluator may differ; otherwise a Repository observation could never contradict a Command adapter, contrary to P0-W24.

### Freshness and currentness

`freshness_rule` is exactly one of:

```text
same_repository_state
same_patch_and_repository_state
same_command_registration_and_repository_state
manual_same_repository_state
```

Rules:

- T01 has no `time_bound` rule and no `freshness_ttl_seconds` field or column;
- an unknown freshness rule or any TTL attribute is rejected by application validation, and the table `CHECK` permits only the four accepted state-based values;
- a direct SQL statement naming a TTL column fails because no such column exists; negative, zero, textual, fractional, positive, and overflow TTL values therefore have no durable representation;
- time alone never refreshes or stales Evidence; re-observation, re-execution, explicit invalidation, or a changed bound state determines currentness;
- Evidence is never updated from current to stale. A later evaluation derives stale currentness while retaining the immutable historical record.

The pure currentness API is:

```elixir
Kiln.Evidence.Currentness.evaluate(
  [%Kiln.Evidence{}],
  %Kiln.Evidence.Currentness.Context{}
)
```

The explicit Context contains:

```text
current_subject_state_digest
current_repository_state_digest
current_patch_id | null
current_patch_digest | null
current_patch_result_digest | null
current_host_profile_digest | null
current_command_registration_digest | null
current_command_result_id | null
current_evaluator_digest
artifact_integrity_by_id
invalidated_at | null
evaluated_at
```

The caller supplies at most 256 immutable candidate records plus that Context. `artifact_integrity_by_id` contains one verified, corrupt, missing, or unknown observation for every referenced Artifact. More than 256 candidates returns precondition `limit_exceeded` and no partial view. The function performs no Store, filesystem, clock, or process access and returns an `EvidenceView` for every candidate with `freshness: current | stale | unknown`, `contradiction: none | present | unknown`, `invalidated_at`, and at most 256 contradicting IDs.

A required binding mismatch or explicit invalidation returns `stale`. A required current binding or integrity observation that is unavailable returns `unknown`. Complete current `pass` and `fail` records for the same criterion revision and exact binding return `contradiction: present` for every member of that set. Time values may be carried for provenance but have no freshness effect.

T01 does not persist invalidation facts. `invalidated_at` is an explicit currentness input owned by the later accepted criterion/evaluation path. A caller may supply `null` only when it can prove no applicable invalidation exists; absence of that proof produces `freshness: unknown`, never an assumed current result.

### Artifact association

`artifact_ids` may be empty because deterministic Repository or user observations can be complete without a retained byte Artifact. When one or more are present:

- SQLite foreign keys require every ID in `evidence_artifacts` to reference an existing Artifact metadata row;
- the canonical list is unique and contains at most 32 IDs;
- `registered_command` Evidence requires a non-null `command_result_id`, but may have no Artifact when the bound result retained no output bytes;
- before Evidence insertion, T01 reopens the relative Artifact path below the accepted root, rehashes the bytes, and compares size and digest to metadata;
- a missing, path-escaping, special, unreadable, size-mismatched, or digest-mismatched Artifact produces protected `integrity` and no Evidence row;
- an existing Artifact record remains a valid independent record when a later Evidence attempt fails. Artifact and Evidence are distinct domain facts, so this is not partial Evidence persistence.

### Public APIs and ownership

The Artifact write API is authoritatively:

```elixir
Kiln.Artifact.Store.put(ready_store, %Kiln.Artifact.PutRequest{})
Kiln.Artifact.Store.fetch(ready_store, artifact_id)
```

The write is exactly `put/2`. The first argument is the ready Store value returned by `Kiln.Store.start/1`, extended with the accepted state path and derived Artifact root. The second argument contains the bytes, immutable metadata, caller-supplied UUIDv7 `artifact_id`, idempotency key, and recorded time. `fetch/2` is a read-only metadata lookup that reopens and verifies the blob and returns the immutable record plus derived `integrity_status`. No public `put/3` exists.

The Evidence APIs are:

```elixir
Kiln.Evidence.new(attrs)
Kiln.Evidence.Store.record(ready_store, %Kiln.Evidence.RecordRequest{})
Kiln.Evidence.Store.fetch(ready_store, evidence_id)
Kiln.Evidence.Currentness.evaluate(records, %Kiln.Evidence.Currentness.Context{})
```

`new/1` is pure construction and validation. `record/2` owns the durable Evidence write. Its typed request separates the immutable `evidence` payload from an `admission_context` used only for an unseen-key current-state precondition. `fetch/2` is a read-only integrity-checked lookup. `Currentness.evaluate/2` is the only T01 re-evaluation surface and is pure. No Gate, Command, or later application context owns T01 persistence implicitly.

Artifact publication owns filesystem staging and one outer SQLite metadata transaction. Evidence recording owns one outer `BEGIN IMMEDIATE` transaction. Neither API opens a nested transaction, calls the other write API, or accepts a caller callback as transaction logic.

### Idempotency

Both primary tables have a unique `idempotency_key` and stored `request_digest`. For Evidence, the digest covers only persistent record identity and excludes `admission_context` and every later currentness context:

- an unseen key performs one write;
- the same key and same request digest first verifies the stored row and its Artifact links, then returns the previously committed record with `status: replayed` and writes nothing;
- the same key and a different request digest returns a typed `:idempotency_conflict` protected as `integrity` and writes nothing;
- matching content digest alone is not a replay key and does not collapse distinct Artifact provenance records;
- matching Evidence record digest under a different idempotency key may create a separate immutable observation because producer, time, or workflow intent can differ.

Evidence replay ordering is exact: validate envelope bounds and digest shapes, classify the idempotency key, verify and return an exact replay, reject a conflicting key, and only for an unseen key evaluate the supplied admission context before insertion. A changed current Repository, host, Command, Artifact, or invalidation state never turns an exact persistent retry into an idempotency conflict. The caller re-evaluates the returned or fetched record with `Currentness.evaluate/2`.

### Protected classifications

Protected classifications are deterministic outcomes, not values a caller may claim.

| Classification | Exact semantics | Durable behavior | Failure or return behavior |
| --- | --- | --- | --- |
| `contradiction` | Complete current `pass` and `fail` records conflict for the same criterion revision and exact composite binding | Preserve all immutable Evidence rows; store no mutable contradiction flag | `record/2` may return a derived post-insert view; `Currentness.evaluate/2` reports `present` with bounded IDs and aggregate pass remains unavailable |
| `stale` | An unseen proposed record fails its admission binding, or a fetched record no longer matches the supplied currentness context | Reject a newly stale write with no Evidence row; retain already recorded historical Evidence unchanged | `record/2` returns protected `stale` only for unseen-key admission; `Currentness.evaluate/2` reports historical staleness without mutation |
| `incomplete` | Required observation content is partial, truncated, missing, or unknown | A `blocked` or `unknown` record may commit truthfully with its completeness; `pass` or `fail` with non-complete content is rejected and writes no row | return committed `incomplete` for truthful `blocked` or `unknown`, or protected rejection for an unsupported pass/fail |
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

Evidence recording validates envelope bounds and digests, then opens one `BEGIN IMMEDIATE` transaction. It classifies idempotency first. An exact replay is integrity-verified and returned without admission re-evaluation; a conflict writes nothing. Only an unseen key proceeds through admission-state validation, plural Artifact verification, Evidence insertion, association and warning insertion, and a pure post-insert currentness/contradiction projection. A fault at any write point rolls back the new Evidence row and all child rows while leaving prior Artifact and Evidence records unchanged.

## Requirements

- **P1-S02-T01-R01:** The Store shall expose an Artifact root below the accepted `$KILN_HOME` and shall never store Artifact content bytes in SQLite.
- **P1-S02-T01-R02:** The system shall persist provenance-bearing Artifact metadata separately from content identity, using UUIDv7 `artifact_id` and SHA-256 `content_digest`.
- **P1-S02-T01-R03:** `Kiln.Artifact.Store.put/2` shall accept exactly a ready Store and one typed request, `fetch/2` shall provide integrity-checked read access, and no public `put/3` shall exist.
- **P1-S02-T01-R04:** Artifact publication shall use staged, synced, digest-verified, same-directory atomic placement before committing metadata that references the blob.
- **P1-S02-T01-R05:** Evidence shall carry required `result: pass | fail | blocked | unknown`, method, producer, exact subject and Repository-state bindings, nullable Patch, host-profile, Command-registration, and Command-result bindings, plural Artifact bindings, completeness, and one accepted state-based freshness rule.
- **P1-S02-T01-R06:** `Kiln.Evidence.Store.record/2` shall own the durable Evidence path and one outer immediate transaction; no later Gate path shall be the implicit persistence owner.
- **P1-S02-T01-R07:** The runtime shall use `Kiln.Store.Canonical.encode/1` and schema-bound digests as byte authority; runtime JSON Schemas shall remain shape validators, and the first-month conformance view shall map stored `result` to `status` plus derived freshness and contradiction without mutation.
- **P1-S02-T01-R08:** Application validation and SQLite shall enforce the declared Artifact-byte and metadata bounds, bounded vocabularies, digest shapes, result/completeness safety, plural Artifact foreign keys, and state-based freshness vocabulary.
- **P1-S02-T01-R09:** T01 shall implement only the four P0-W24 state-based freshness rules. `time_bound` and every TTL field or column are forbidden; invalid application and direct-SQL attempts shall write nothing.
- **P1-S02-T01-R10:** Contradiction, stale, incomplete, and integrity outcomes shall follow the protected-classification table and shall never create a false pass, dangling Evidence association, or partially committed Evidence row.
- **P1-S02-T01-R11:** Exact retries shall replay by idempotency key and persistent request digest before admission-state evaluation; currentness context shall not affect persistent request identity, and conflicting key reuse shall return integrity-classified idempotency failure and write nothing.
- **P1-S02-T01-R12:** Migrations 0003 and 0004 shall be forward-only, checksummed, atomic per migration, compatible with fresh and upgraded v1 stores, and shall not change `kiln-state/v1`.
- **P1-S02-T01-R13:** Artifact and Evidence shall remain plain data and functions; no process, registry, pool, retry loop, savepoint, nested transaction, provider, Repository source access, Patch, Command, Gate, completion, or Receipt surface shall be added.
- **P1-S02-T01-R14:** Secrets, denied paths, raw transcript, and Repository source content shall not enter metadata or ordinary errors; Artifact sensitivity and retention shall remain explicit.
- **P1-S02-T01-R15:** `Evidence.Store.fetch/2` and pure `Evidence.Currentness.evaluate/2` shall re-evaluate immutable records against explicit current bindings and peer Evidence without persistence, ambient time, or idempotency effects.
- **P1-S02-T01-R16:** The migration runner shall apply compound SQLite statements whose bodies contain internal semicolons, so migration 0004 can create the aborting aggregate trigger required by this plan. The change is confined to compound-statement recognition in `Kiln.Store.Migrations.statements/1`. Migrations 0001 through 0003 shall apply with unchanged checksums and an unchanged executed statement sequence, and migration discovery, `schema_migrations` bookkeeping, per-migration transaction ownership, rollback, and error classification shall remain unchanged.

## Security boundary

Allowed:

- extend the ready Store value with the accepted state path and derived Artifact root;
- add pure Artifact and Evidence data, validators, canonical-record builders, and Store functions;
- add migrations 0003 and 0004 with database constraints and indexes justified by exact lookup or idempotency needs;
- add descriptive runtime JSON Schemas;
- add deterministic temporary-root and SQLite fixtures;
- use existing Store error classes with domain-specific codes;
- extend `Kiln.Store.Migrations.statements/1` only far enough to recognize a compound SQLite statement, so migration 0004 can create its aborting aggregate trigger.

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

1. Add Artifact record, put-request, and Store modules with exact `put/2`, integrity-checked `fetch/2`, content-addressed filesystem placement, metadata persistence, integrity verification, and idempotent replay.
2. Add Evidence record, record-request, validation, and Store modules with explicit result and accepted bindings, durable `record/2`, integrity-checked `fetch/2`, unseen-key admission precondition, plural Artifact verification, protected classification, and idempotency.
3. Add pure currentness Context, Evidence-view projection, state-based freshness, and contradiction evaluation without implementing criterion aggregation.
4. Extend the ready Store value with its state path and a derived Artifact root below the same accepted Kiln home.
5. Add `0003_artifacts.sql` for provenance metadata and `0004_evidence_records.sql` for immutable Evidence, child associations, warnings, direct-write constraints, and bounded indexes.
6. Add `kiln.artifact/v1` and `kiln.evidence/v1` runtime Schemas as descriptive shape validation, with canonical bytes owned only by `Kiln.Store.Canonical`.
7. Add deterministic tests for byte placement, record identity, association integrity, transaction rollback, direct-SQL constraints, restart, idempotency, currentness, conformance projection, and every protected classification.
8. Extend the existing Store migration and owner-machine diagnostic tests without changing the store-format identifier.
9. Extend the migration runner's statement splitter to recognize a compound `CREATE TRIGGER ... BEGIN ... END;` statement, preserving the exact executed statement sequence and checksums of migrations 0001 through 0003.

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `lib/kiln/store.ex` | ready Store path and derived Artifact-root data | Proposed |
| `lib/kiln/artifact.ex` | immutable Artifact record | Proposed |
| `lib/kiln/artifact/put_request.ex` | exact typed `put/2` request | Proposed |
| `lib/kiln/artifact/store.ex` | filesystem publication, integrity-checked fetch, metadata, integrity, idempotency | Proposed |
| `lib/kiln/evidence.ex` | immutable Evidence and pure `new/1` validation | Proposed |
| `lib/kiln/evidence/record_request.ex` | immutable payload plus unseen-key admission context, with separate persistent request identity | Proposed |
| `lib/kiln/evidence/currentness.ex` | pure state-based freshness, contradiction, and first-month view projection | Proposed |
| `lib/kiln/evidence/currentness/context.ex` | explicit current subject, Repository, Patch, Command, host, Artifact, invalidation, and evaluator bindings | Proposed |
| `lib/kiln/evidence/store.ex` | durable `record/2`, integrity-checked `fetch/2`, association checks, protected classification | Proposed |
| `priv/store/migrations/0003_artifacts.sql` | Artifact metadata and idempotency constraints | Proposed |
| `priv/store/migrations/0004_evidence_records.sql` | Evidence, result, plural association, warning, vocabulary, bounds, freshness, and idempotency constraints | Proposed |
| `priv/schemas/kiln.artifact/v1.json` | descriptive Artifact v1 shape | Proposed |
| `priv/schemas/kiln.evidence/v1.json` | descriptive Evidence v1 shape | Proposed |
| `test/kiln/artifact/` | publication, integrity, replay, and failure fixtures | Proposed |
| `test/kiln/evidence/` | construction, persistence, replay ordering, currentness, conformance projection, classification, and rollback fixtures | Proposed |
| `test/kiln/store/migrations_test.exs` | fresh, upgrade, direct-write, failed-migration, compound-statement, and replay coverage | Proposed |
| `lib/kiln/store/migrations.ex` | compound-statement support in `statements/1` only, sufficient for a SQLite trigger body containing internal semicolons | Proposed |
| `test/kiln/store_test.exs` | ready Store Artifact-root and restart coverage | Proposed |
| `scripts/diagnostics/p1-s01-store-host` | additive 0003/0004 owner-machine observations | Proposed only if the existing diagnostic requires it |

No other path is authorized. Discovery that another path is necessary requires plan adjudication before implementation continues.

## Migration and rollback contract

Migration `0003_artifacts.sql` creates metadata only. It includes:

- primary key on UUIDv7 `artifact_id`;
- unique `idempotency_key` and stored `request_digest`;
- bounded `CHECK` constraints for every vocabulary;
- digest, Artifact content size from 0 through 16,777,216 bytes, media-type, relative-location, identifier, idempotency, and non-empty owner/producer constraints;
- indexes only for idempotency, content digest, owner, and producer lookups exercised by T01 tests.

Migration `0004_evidence_records.sql` includes:

- primary key on UUIDv7 `evidence_id`;
- unique `idempotency_key` and stored request and record digests;
- `evidence_artifacts` child rows with foreign keys to Evidence and Artifact, unique Artifact IDs per Evidence, and positions from 0 through 31;
- `evidence_warnings` child rows with positions from 0 through 63, 1,024-byte item limits, and an aborting aggregate limit of 16,384 bytes;
- bounded byte-length `CHECK` constraints for identifiers, rationale, result, method, completeness, the four accepted freshness rules, digests, and required non-empty fields;
- Patch ID, digest, and result digest are either all null or all non-null;
- `registered_command` requires non-null Command registration, Command result, and host-profile bindings;
- `result IN ('pass', 'fail')` requires `completeness = 'complete'`;
- no `time_bound` vocabulary and no TTL column;
- indexes only for idempotency, criterion/revision/composite binding, Artifact reference, Command result, and producer queries exercised by T01.

The application additionally rejects a canonical Artifact metadata request or Evidence record request over 65,536 bytes before opening a transaction. The database independently enforces every persisted scalar and child-count bound. SQLite measures text bounds as `length(CAST(value AS BLOB))` so multibyte input cannot bypass byte limits. No migration or trigger truncates content.

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
  - **Given** each accepted result and method plus Repository, nullable Patch, host/environment, nullable Command, and plural Artifact bindings;
  - **When** `Evidence.new/1`, `Evidence.Store.record/2`, `fetch/2`, and first-month projection run;
  - **Then** the immutable record carries `pass | fail | blocked | unknown`, canonical record digest, producer, exact composite binding, completeness, and freshness rule; it survives restart; and its `EvidenceView` satisfies P0-W24 and the active conformance projection without mutating the record.
  - **Evidence:** vocabulary, binding cross-product, plural-association, canonical digest, persistence, restart, and conformance tests.
- **P1-S02-T01-AC06 — Accepted freshness boundary**
  - **Given** all four accepted state-based rules plus `time_bound`, unknown rules, and absent, negative, zero, positive, fractional, textual, and overflow TTL attributes;
  - **When** each is attempted through Elixir and direct SQL;
  - **Then** only the four P0-W24 state-based rules can commit, no TTL has a field or column representation, and every `time_bound` or TTL attempt leaves zero rows.
  - **Evidence:** application vocabulary matrix, table introspection, direct-SQL negative matrix, and row-count proof.
- **P1-S02-T01-AC07 — Idempotency and collision**
  - **Given** exact retries, same-key/different-request attempts, and an exact Evidence retry after admission/currentness state changes;
  - **When** persistence runs concurrently or sequentially through the one writer;
  - **Then** persistent identity is classified before unseen-key admission, exact retry returns the integrity-checked original without a second row, changed currentness is reported only by `Currentness.evaluate/2`, conflicting persistent reuse returns integrity-classified idempotency failure, and no existing row changes.
  - **Evidence:** replay-order, changed-context, conflict, row-count, and immutable-row fixtures.
- **P1-S02-T01-AC08 — Contradiction**
  - **Given** current complete `pass` and `fail` Evidence for the same criterion revision and subject binding;
  - **When** both observations record and `Currentness.evaluate/2` receives them with their current bindings;
  - **Then** both immutable observations remain committed, every derived view reports `contradiction: present` with bounded IDs, and no passing aggregate or mutable overwrite is created.
  - **Evidence:** contradiction persistence, pure projection, and restart fixtures.
- **P1-S02-T01-AC09 — Stale binding**
  - **Given** an unseen proposed Evidence record whose admission binding differs from current state and an existing record fetched after its bound state changes;
  - **When** `record/2` handles the unseen key and `Currentness.evaluate/2` handles the fetched record;
  - **Then** unseen admission returns protected `stale` with no row, while the existing record is fetched unchanged and its pure view reports `freshness: stale` without an idempotency decision or write.
  - **Evidence:** stale-admission, fetch, changed-state currentness, row-count, and immutable-byte fixtures.
- **P1-S02-T01-AC10 — Incomplete proof**
  - **Given** partial, truncated, missing, or unknown observation content;
  - **When** each Evidence result is attempted;
  - **Then** truthful `blocked` or `unknown` Evidence may commit as `incomplete`, while `pass` and `fail` are rejected with no row unless completeness is `complete`.
  - **Evidence:** completeness/result cross-product and row-count fixtures.
- **P1-S02-T01-AC11 — Integrity and association**
  - **Given** any missing, corrupt, size-mismatched, path-escaping, special-file, duplicate, over-count, or foreign-key-invalid member of the plural Artifact association and record-digest faults;
  - **When** Evidence persistence runs;
  - **Then** it returns protected `integrity` or precondition `limit_exceeded` as specified, rolls back the whole Evidence transaction and all child rows, and creates no dangling association.
  - **Evidence:** plural Artifact-integrity, count, duplicate, child-row rollback, and direct-SQL foreign-key fixtures.
- **P1-S02-T01-AC12 — Transaction and scope boundary**
  - **Given** the implementation call graph and fault injection;
  - **When** reviewed and tested;
  - **Then** each write has one explicit outer transaction owner, nested use is rejected, no process exists for Artifact or Evidence, and no denied later capability is reachable.
  - **Evidence:** transaction-call inspection, nested-use test, dependency scan, and runtime-path review.
- **P1-S02-T01-AC13 — Bounds and overflow**
  - **Given** every declared byte, scalar, warning, Artifact-reference, rationale, and canonical-request bound at its maximum and one unit over, including multibyte UTF-8 cases;
  - **When** Artifact and Evidence calls and applicable direct-SQL paths run;
  - **Then** maximum values persist exactly, every overflow returns `limit_exceeded` or aborts the direct transaction as specified, no value is silently truncated, and row and blob counts remain unchanged after rejection.
  - **Evidence:** boundary matrix, multibyte fixtures, direct-SQL constraints and triggers, no-truncation comparisons, and zero-effect proof.
- **P1-S02-T01-AC14 — Exact-state package gate**
  - **Given** the exact replacement implementation head;
  - **When** the complete Repository and owner-machine validation runs;
  - **Then** all checks pass and completion Evidence binds only that head.
  - **Evidence:** exact-head CI, OD-02 diagnostic, final diff, and recorded digest.
- **P1-S02-T01-AC15 — Compound migration statements**
  - **Given** migrations 0001 through 0003 and a migration containing `CREATE TRIGGER ... BEGIN ...; ... END;`;
  - **When** the runner discovers and applies them against fresh and upgraded stores;
  - **Then** migrations 0001 through 0003 apply with identical checksums and an identical executed statement sequence, the trigger is created and fires, exactly 16,384 aggregate warning bytes commit, 16,385 aggregate bytes abort the statement, and a failed compound migration records no `schema_migrations` checksum.
  - **Evidence:** statement-splitter unit matrix, trigger creation and firing fixtures, aggregate boundary pair, checksum and statement-sequence stability proof, and failed-compound-migration rollback proof.

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

Owner-machine verification must record the exact implementation head, host profile, filesystem, Exqlite, SQLite, migration checksums, Artifact root, restart result, bounds matrix, and protected fault matrix. It must confirm `store_format = kiln-state/v1` and preserve P1-S01 observations.

## Demo contribution

```text
P1-S02-D01 prerequisite: publish deterministic Artifacts through put/2, record one result-bearing Evidence item with the accepted explicit bindings and plural Artifact association, restart, replay both exact idempotency keys under a changed currentness context, fetch the same immutable records, and derive a current first-month Evidence view without running a provider, Command, Gate, or completion evaluator.
```

## Required completion Evidence

| Evidence ID | Acceptance criterion | Required Evidence |
| --- | --- | --- |
| P1-S02-T01-E01 | AC01 | fresh/upgrade/fault migration and restart results |
| P1-S02-T01-E02 | AC02 | content digest, blob sharing, UUID identity, SQL-no-bytes, and replay results |
| P1-S02-T01-E03 | AC03 | staged publication fault matrix and no-dangling-row proof |
| P1-S02-T01-E04 | AC04 | exact `put/2` export and no-`put/3` proof |
| P1-S02-T01-E05 | AC05 | result vocabulary, accepted binding, plural association, conformance projection, canonical digest, persistence, and restart results |
| P1-S02-T01-E06 | AC06 | accepted freshness vocabulary, absent TTL, application, and direct-SQL negative matrix |
| P1-S02-T01-E07 | AC07 | exact replay ordering, changed evaluation context, conflict, concurrency, and immutable-row results |
| P1-S02-T01-E08 | AC08 | contradiction persistence and pure projection results |
| P1-S02-T01-E09 | AC09 | stale admission, fetch, pure historical-currentness, and no-mutation results |
| P1-S02-T01-E10 | AC10 | completeness/result cross-product results |
| P1-S02-T01-E11 | AC11 | Artifact-integrity, foreign-key, rollback, and zero-row results |
| P1-S02-T01-E12 | AC12 | transaction call graph, nested-use, dependency, and denied-surface review |
| P1-S02-T01-E13 | AC13 | numeric boundary, multibyte, overflow, direct-SQL, and no-truncation results |
| P1-S02-T01-E14 | AC14 | exact-head CI, owner-machine diagnostic, final diff, and plan digest binding |
| P1-S02-T01-E15 | AC15 | splitter matrix, trigger creation and firing, aggregate boundary pair, checksum and statement-sequence stability, and failed-compound-migration rollback results |

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

**Result:** Corrected replacement plan owner-accepted against canonical `main` `e57678874a36de1700aa666413b51aae31ea9b12` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072`, then amended by P0-W43 to authorize the bounded migration-runner compound-statement change required by P1-S02-T01-R16. Authorized, not implemented, not verified, and not accepted.

### Rejected-plan history

- PR #48 candidate commit `60367874bfc3c0e6d8cbd736f58e1ae17938943b` was premature.
- The correctly authorized adjudication head was `7ba158bddff76ade9aca79cb8501e675bd0cded9`.
- Exact-state CI run `31294035484` passed Repository checks.
- Technical adjudication rejected the candidate for missing Evidence result, missing Evidence persistence ownership, false protected-classification claims, inadequate TTL database constraints, and `put/2` versus `put/3` disagreement.
- PR #48 closed without merge. No runtime code from it entered `main`.
- P0-W37 removed the consumed authorization and integrated through PR #52 at `f9b5a312ac31ee4015025a87bcd3cec199b12297`.
- The corrected plan was integrated through PR #56 at `e57678874a36de1700aa666413b51aae31ea9b12`; PR #53 remained the historical unmerged predecessor.

The corrected plan preserves that negative Evidence. It does not retroactively authorize, accept, or rehabilitate any rejected implementation state.

### Current acceptance status

| Stage | Status | Result |
| --- | --- | --- |
| Corrected planning | Accepted | owner-accepted against canonical `main` `e57678874a36de1700aa666413b51aae31ea9b12` from reviewed Proposed-state digest `fb4dcad0d278ca096c383d835b19dc9bc1d66ca9dc66c7feaddc6daa728ea072` |
| Owner acceptance | Granted | P0-W41 records the explicit owner decision |
| Implementation authorization | Granted | P0-W42 created `docs/authorizations/P1-S02-T01.authorization`; P0-W43 reissues it against the amended plan digest and base `1243b8f27a594c9440638964a83b56c74774ba28` |
| Replacement implementation | Not started | `work/p1-s02-t01-artifact-evidence-substrate-v2` exists at canonical `main` with zero unique commits |
| Verification | Not run | only a later exact replacement head can supply runtime Evidence |
| Acceptance | Not granted | implementation and exact completion Evidence do not exist |

### Required next action

A later, separate governance action must record the Accepted-state plan digest, the new canonical `main` SHA produced by the P0-W41 merge, owner, time, and bounded scope in a new T01 authorization on canonical `main`. P0-W42 satisfied that action. P0-W43 amends this plan for P1-S02-T01-R16 and reissues the authorization record against the amended digest, because amending the plan invalidates the previous `plan_sha256` binding. Only after P0-W43 integrates may implementation begin on `work/p1-s02-t01-artifact-evidence-substrate-v2`; PR #48 must remain closed and unmerged.
