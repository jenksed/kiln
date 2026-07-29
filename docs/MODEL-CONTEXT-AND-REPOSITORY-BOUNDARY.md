# Model, Context, and Repository Boundary

**Document type:** Focused model and disclosure authority  
**Decision status:** Proposed by P0-W22; owner acceptance required  
**Integration status:** Proposed on `work/p0-w22-model-context-repository-boundary`  
**Implementation status:** Not implemented  
**Owner decision:** OD-01 integrated through ADR-0021  
**Build authorization:** Not issued

## Authority

This specification owns first-month decisions for:

- the only real provider and deterministic fake;
- provider request, stream, result, timeout, cancellation, malformed-result, usage, and retry behavior;
- the sealed Context package and manifest;
- model-visible Tool projection;
- bounded Repository observation, search, and read;
- Artifact reads used during one invocation;
- source disclosure and provider egress;
- secret and sensitive-content screening;
- provider request and response retention.

It does not own:

- Session, Task, or Run lifecycle;
- journal, projection, migration, transaction, or restart semantics;
- Patch Approval or source mutation;
- registered Command execution;
- criterion Evidence, completion, Receipt, or acceptance;
- CLI syntax or presentation.

P0-W21 owns lifecycle and persistence. If this document uses lifecycle or operation examples, those examples must conform to the integrated P0-W21 authority.

## Accepted constraints

P0-W22 consumes these accepted decisions:

- MiniMax is the only initial real provider;
- one deterministic fake provider is required;
- there is no fallback, router, ensemble, or silent provider substitution;
- only one sealed Context package and required provider metadata may leave the machine;
- source excerpts require an accepted Project disclosure policy;
- Context does not grant authority;
- four or fewer Tool schemas can enter one provider request;
- Repository content is untrusted data;
- reference repositories, runtime Skills, LSP, Tree-sitter, persistent indexes, protocols, and hosted retrieval are disabled;
- large or unbounded results remain Artifacts;
- a model can propose work but cannot approve, apply, verify, or accept it.

# 1. Decision summary

P0-W22 accepts these focused decisions:

1. Use MiniMax through its OpenAI-compatible text endpoint.
2. Use model `MiniMax-M2.7` as the first configured model.
3. Use direct bounded HTTP and JSON mapping behind a Kiln-native provider behaviour.
4. Use streaming for the real provider and deterministic scripted events for the fake.
5. Set `reasoning_split` when supported. Provider-native reasoning remains transient and is never journal, Context, Evidence, Receipt, or normal Artifact content.
6. Do not retry a dispatched provider request automatically.
7. Treat cancellation after dispatch as an unknown provider effect unless a terminal provider result was observed.
8. Seal one ordered Context package before dispatch. Tool calls can add bounded results to the transient invocation conversation, but they cannot mutate the sealed initial package.
9. Load exactly four possible Tools: `repo.search`, `repo.read`, `artifact.read`, and `change.propose`.
10. Project workflow step selects the Tool subset. An unused Tool schema is absent.
11. Use deterministic path, size, encoding, special-file, symlink, ignore, and secret controls before any content becomes model-visible.
12. Default source disclosure to denied until an accepted Project policy allows the exact source class and destination.
13. Persist manifests, normalized requests and results, usage, and digests. Do not persist the raw provider-native reasoning stream or complete raw provider payload by default.
14. Keep provider-side retention an explicit unknown outside Kiln control.

# 2. Provider contract

## 2.1 Provider identity

The first real provider contract is:

```text
provider_id: minimax
api_family: minimax-openai-compatible/v1
endpoint: https://api.minimax.io/v1/chat/completions
model: MiniMax-M2.7
fallback: none
```

The endpoint and model are configuration values validated against this accepted first-provider profile. A different endpoint, model family, or provider requires a later accepted decision. A model version change does not occur silently.

## 2.2 Authentication

The provider request uses an opaque credential reference resolved at dispatch.

Rules:

- default environment reference: `MINIMAX_API_KEY`;
- the key value never enters the journal, Context package, Tool result, transcript, Artifact metadata, Receipt, CLI output, or error detail;
- logs can record only credential reference name and resolution status;
- a missing or empty key blocks dispatch;
- the key is sent only in the provider authorization header;
- Kiln does not write the key to a Project file or generated configuration.

## 2.3 Normalized invocation request

The Kiln-native request contains:

```text
invocation_id
session_id
run_id
operation_id
provider_profile_id
model_id
context_package_id
context_package_digest
tool_projection_id
tool_projection_digest
max_output_tokens
timeout_ms
stream
request_created_at
authority_reference
disclosure_decision_references
```

The provider adapter builds the provider request from this request and the sealed Context package. Provider-specific fields do not enter domain state unless they are retained metadata.

## 2.4 Provider request mapping

The initial mapping uses:

```text
model: MiniMax-M2.7
stream: true
max_completion_tokens: 8192
temperature: 1.0
top_p: 0.95
tools: selected fixed Tool schemas
extra_body.reasoning_split: true
```

Rules:

- `n` is one;
- image, audio, file, and multimodal inputs are absent;
- unsupported OpenAI-compatible parameters are not sent;
- sampling fields are fixed by the provider profile, not by model output;
- the initial Context package is represented as ordered system and user text derived from accepted item classes;
- Tool results are appended only inside the same live invocation conversation;
- a Tool result cannot add a new Tool schema or authority.

## 2.5 Streaming events

The adapter normalizes provider input into these transient events:

```text
response_started
visible_text_delta
tool_call_started
tool_arguments_delta
tool_call_completed
usage_observed
response_completed
provider_error
stream_ended
```

Provider-native reasoning deltas are consumed only as required to maintain the active provider conversation. They are not exposed as Kiln reasoning, persisted, summarized as Evidence, or included in a Receipt.

A visible response is complete only after a terminal provider completion event and valid final mapping.

## 2.6 Result contract

A terminal normalized result contains:

```text
invocation_id
provider_id
model_id
provider_request_id | null
status
visible_message_artifact_id | null
normalized_tool_calls
finish_reason
usage
input_sensitive_flag | unknown
output_sensitive_flag | unknown
warnings
provider_metadata
started_at
completed_at
result_digest
```

`status` is one of:

```text
succeeded
failed
canceled_before_dispatch
unknown
```

There is no `canceled_after_dispatch` success-like state. If Kiln aborts a dispatched request without a terminal provider observation, the result is `unknown`.

## 2.7 Timeout

Initial limits:

```text
connect_timeout_ms: 10_000
first_byte_timeout_ms: 60_000
idle_stream_timeout_ms: 60_000
total_invocation_timeout_ms: 600_000
```

A timeout before dispatch is a known local failure.

A timeout after request dispatch and before a terminal provider result is an unknown provider effect. Kiln closes the connection, records the uncertainty through the P0-W21 operation boundary, and does not retry automatically.

## 2.8 Cancellation

Cancellation behavior:

| Boundary | Result |
| --- | --- |
| before credential resolution | `canceled_before_dispatch` |
| after credential resolution but before request bytes | `canceled_before_dispatch` |
| after dispatch with terminal provider result already observed | use the observed terminal result |
| after dispatch without terminal result | `unknown` |

Closing a local HTTP connection does not prove that the hosted provider stopped processing or billing the request.

P0-W26 can deepen cancellation after runtime Evidence exists. It cannot revise this conservative first-month classification without an accepted authority change.

## 2.9 Retry

There is no automatic provider retry.

Rules:

- local validation failure never dispatches;
- DNS, connect, TLS, HTTP, rate-limit, provider, stream, timeout, malformed-result, and connection-loss failures return one explicit result;
- a user can request a new invocation only through a new workflow action after inspecting the prior result;
- if prior dispatch is uncertain, the Run remains subject to P0-W21 orphan and reconciliation rules;
- a new invocation has a new invocation and operation identity;
- Kiln does not switch provider or model.

## 2.10 Malformed or unsupported provider data

Return `failed` before any model effect is accepted when:

- a required response field is absent;
- Tool arguments are not valid JSON;
- a Tool name is not in the selected projection;
- a Tool call exceeds count, byte, or time limits;
- a finish reason is unsupported;
- usage data has an invalid type;
- visible content exceeds accepted output limits;
- a provider event sequence is invalid but the stream ended with a known error.

Return `unknown` when the stream or connection ends and Kiln cannot prove whether a valid terminal provider result existed.

## 2.11 Usage

Retain normalized provider-reported usage when present:

```text
input_tokens | null
output_tokens | null
total_tokens | null
reasoning_tokens | null
cache_read_tokens | null
cache_creation_tokens | null
```

Usage is accounting metadata. It is not Evidence of correct work.

# 3. Deterministic fake provider

## 3.1 Purpose

The fake proves Kiln provider-boundary behavior without network access, credentials, cost, nondeterminism, or provider availability.

It is not a second provider option in the product. It is a test implementation of the same behaviour.

## 3.2 Script contract

A fake scenario is an ordered immutable script:

```text
scenario_id
expected_request_digest
expected_tool_projection_digest
events
expected_terminal_status
expected_result_digest
```

Supported scripted events include:

- visible text chunks;
- complete Tool calls;
- malformed Tool arguments;
- provider error before response;
- provider error after partial response;
- timeout before first byte;
- idle timeout;
- connection loss;
- explicit usage;
- terminal success;
- cancellation before dispatch;
- cancellation after dispatch with unknown effect.

## 3.3 Determinism

The fake:

- performs no network access;
- reads no environment credentials;
- uses a fixed monotonic fake clock supplied by the test;
- emits only scripted events;
- verifies request and Tool-projection digests;
- fails on unexpected Tool call or extra turn;
- produces byte-stable normalized results.

# 4. Sealed Context package

## 4.1 Package identity

Each invocation receives one immutable package:

```text
context_package_id
context_schema
session_id
run_id
workflow_step
objective_revision
criteria_revision
repository_observation_id
repository_state_digest
policy_snapshot_id
provider_profile_id
ordered_items
tool_projection_id
limits
exclusions
created_at
package_digest
```

The digest covers the schema identifier, ordered item manifests, Tool projection digest, accepted limits, exclusions, provider destination, and disclosure decision references.

The package does not contain credential values.

## 4.2 Ordered item classes

The initial package can contain these classes in this order:

1. `system_contract` — bounded Kiln rules and output contract;
2. `objective` — accepted objective revision;
3. `criteria` — accepted criterion identifiers and text;
4. `constraints_and_exclusions`;
5. `workflow_state` — current step, pending work, and safe next action;
6. `repository_observation` — root identity, commit, branch, dirty summary, and state digest;
7. `project_instructions` — accepted active Project instructions only;
8. `source_excerpt` — selected active-Repository text ranges;
9. `current_failure_or_warning`;
10. `current_claim_or_proposal_summary` when required by the step;
11. `artifact_excerpt` when explicitly selected;
12. `output_contract`;
13. `tool_projection`.

An item class not needed for the workflow step is absent.

## 4.3 Context item manifest

Every item records:

```text
item_id
item_class
source_kind
source_reference
authority
trust
sensitivity
repository_state_binding | null
freshness
selection_reason
transformation
original_digest | null
included_digest
byte_count
token_estimate
disclosure_mode
disclosure_decision_id | null
```

`authority` cannot be elevated by source content. Repository source and comments use `authority: untrusted_data` unless the item is an accepted Project instruction selected through the Project authority path.

## 4.4 Limits

Initial package limits:

```text
maximum_context_items: 64
maximum_source_files: 24
maximum_source_excerpts: 48
maximum_single_source_excerpt_bytes: 16_384
maximum_total_source_excerpt_bytes: 262_144
maximum_artifact_excerpt_bytes: 16_384
maximum_serialized_provider_payload_bytes: 524_288
maximum_estimated_input_tokens: 32_000
maximum_output_tokens: 8_192
maximum_tool_schemas: 4
maximum_tool_calls: 12
maximum_provider_turns: 8
maximum_invocation_elapsed_ms: 600_000
```

If the package exceeds a limit, the Context builder returns a structured blocked result. It does not silently drop an accepted criterion, instruction, warning, or required state binding.

Optional source excerpts are removed by a deterministic lowest-priority rule with explicit exclusions recorded. Required items are never silently truncated.

## 4.5 Inspection

Before dispatch, Kiln can show:

- provider and model;
- package digest;
- item classes and sources;
- files and ranges;
- bytes and token estimate;
- Tool names;
- disclosure decisions;
- exclusions and blocked items;
- warnings and unknowns.

The initial CLI contract is owned by P0-W25. This specification requires that the data be available.

## 4.6 Staleness

A Context package is stale when any bound fact changes, including:

- objective or criteria revision;
- Project instructions or disclosure policy;
- Repository commit, dirty fingerprint, file digest, or selected range;
- Tool schema or limit;
- provider profile or destination;
- current Patch, failure, warning, or required Evidence reference.

A stale package cannot be dispatched. It must be rebuilt and receive a new package identity and digest.

## 4.7 Provider-native transient conversation

Tool calling can require provider-native assistant and Tool messages during one live invocation.

Rules:

- the sealed initial package remains immutable;
- Tool results are appended only to the transient live provider conversation;
- each result is already bounded and normalized by Kiln;
- provider-native reasoning or thinking fields remain transient;
- the live conversation is discarded after terminal normalization;
- durable records contain Tool request and result references, visible final content, usage, warnings, and digests;
- after Worker loss, Kiln does not reconstruct the provider-native conversation from hidden reasoning or replay the invocation.

# 5. Disclosure policy

## 5.1 Default

Remote source disclosure is denied by default.

A Project must contain one accepted policy before any source excerpt can enter a MiniMax package.

## 5.2 Disclosure modes

Each source class or path rule uses one mode:

```text
deny
metadata_only
approved_excerpt
explicit_each_time
local_only
```

Meanings:

- `deny` — neither metadata nor content leaves the machine;
- `metadata_only` — permitted bounded path or language metadata only;
- `approved_excerpt` — accepted policy allows bounded excerpts under matching rules;
- `explicit_each_time` — one user decision is required for the exact package digest;
- `local_only` — content can be inspected locally but cannot enter a hosted-provider package.

## 5.3 Disclosure decision

Every remotely disclosed item references a decision containing:

```text
decision_id
project_id
provider_id
destination
source_class
path_rule
allowed_transformations
maximum_bytes
accepted_by
accepted_at
expires_at | null
policy_revision
```

For `explicit_each_time`, the decision also binds the Context package digest.

## 5.4 Non-overridable denials

Project policy cannot permit:

- credential values;
- private keys;
- authentication cookies or tokens;
- denied secret files;
- Kiln internal state database content;
- provider credentials;
- hidden model reasoning;
- reference Repository source in version 0.1;
- files outside the canonical active Repository root.

## 5.5 Provider-side retention

Kiln does not control or prove hosted-provider storage, logging, abuse review, or deletion behavior.

The Project policy must state that approved data is sent to a hosted MiniMax endpoint. Kiln records the destination and package digest. It does not claim provider-side deletion or local-only processing.

# 6. Repository boundary

## 6.1 Root and observation

One active Repository has:

```text
repository_id
canonical_root
worktree_root
vcs_kind: git
head_commit | null
branch | null
detached
dirty_fingerprint
ignore_policy_digest
observation_time
repository_state_digest
```

The root is resolved before any operation. Every requested path is interpreted relative to the canonical worktree root.

## 6.2 Path rules

Accept only paths that:

- are relative UTF-8 paths;
- normalize without `..` escape;
- remain inside the canonical root after parent-directory resolution;
- identify a regular file or permitted directory traversal;
- do not traverse a symlink;
- are not inside `.git/` or `$KILN_HOME`;
- are not denied by Project or mandatory secret policy.

Deny:

- absolute paths;
- path traversal;
- symlink targets and junction-like escapes;
- sockets, devices, FIFOs, and special files;
- submodule content by default;
- nested Repository content unless explicitly part of the accepted active Repository boundary;
- files outside the selected checkout.

## 6.3 Ignore order

Apply ignores in this order:

1. mandatory Kiln exclusions;
2. mandatory secret-path exclusions;
3. Project deny rules;
4. accepted Repository ignore files;
5. accepted Project include rules, which cannot override mandatory exclusions.

Generated or vendored content is excluded by default when the Repository marks it as generated, ignored, vendor, dependency cache, build output, or lock-internal content. A Project can allow a bounded non-secret file class when needed.

## 6.4 File eligibility

Initial eligible content is regular UTF-8 text.

Limits:

```text
maximum_file_size_for_read: 1_048_576 bytes
maximum_single_read_result: 131_072 bytes
maximum_single_search_result: 65_536 bytes
maximum_search_matches: 100
maximum_line_length_in_result: 4_096 bytes
```

Deny or block:

- NUL bytes;
- invalid UTF-8;
- binary detection;
- file larger than the accepted limit;
- oversized line that cannot be represented safely;
- permission or I/O failure;
- content changed after its observed digest.

A denied or blocked file can be named in local status without disclosing content.

## 6.5 Repository fingerprint

The state digest covers:

- canonical root identity;
- Git HEAD or no-commit state;
- branch or detached state;
- tracked dirty paths and content digests required by the workflow;
- relevant untracked paths under accepted policy;
- ignore-policy digest;
- selected file digests.

The digest is not a substitute for Git. It binds Kiln observations and provider Context to exact local state.

## 6.6 Search

`repo.search` performs bounded deterministic literal text search.

Input:

```text
query
path_prefixes | []
include_globs | []
case_sensitive
maximum_matches <= 100
```

Rules:

- no arbitrary shell;
- no user-supplied regular expression in the first contract;
- search only eligible files;
- results are ordered by normalized path, line, and column;
- each result includes path, line range, bounded excerpt, file digest, and completeness;
- truncated searches return a continuation token bound to query, root, state digest, and prior result boundary;
- a changed Repository state invalidates the continuation token.

## 6.7 Read

`repo.read` returns one bounded text range.

Input:

```text
path
start_line
end_line
expected_file_digest | null
```

Rules:

- maximum returned bytes is 131,072;
- returned content includes normalized path, exact line range, file digest, Repository state digest, byte count, and completeness;
- a digest mismatch returns `STALE_SOURCE` and no content;
- no automatic whole-file retry occurs;
- line endings are reported and content bytes remain unchanged except for safe output framing;
- the provider receives only excerpts that pass disclosure policy and secret screening.

# 7. Secret and sensitive-content controls

## 7.1 Mandatory secret paths

Deny content from common credential and private-key locations, including:

- `.env` and `.env.*` except explicitly non-secret example files;
- `.ssh/`;
- `.aws/`, `.config/gcloud/`, and similar credential stores;
- `.npmrc`, `.pypirc`, `.netrc`, and credential helper files;
- files ending in `.pem`, `.key`, `.p12`, `.pfx`, or known private-key names;
- provider credential files;
- `$KILN_HOME` state, configuration secrets, Artifacts marked secret, and database files.

The exact mandatory list is versioned. Project policy can add denials but cannot remove mandatory denials.

## 7.2 Content screening

Before an excerpt becomes model-visible, run deterministic screening for:

- private-key headers;
- well-formed provider, cloud, Git hosting, package registry, and authentication token patterns;
- high-confidence password or secret assignment patterns in structured configuration;
- authorization headers, cookies, and connection strings with credentials;
- control characters and bidirectional text controls;
- embedded NUL or invalid encoding.

A match blocks the whole candidate excerpt by default.

Kiln does not claim that pattern screening detects every secret. The package manifest records screening version and result. Accepted Project policy remains necessary but is not sufficient to override a secret block.

## 7.3 Redaction

Automatic partial redaction is not the default for source excerpts because it can alter program meaning and line binding.

Allowed transformations are:

- omit the item;
- replace the complete blocked value with a typed placeholder only when a deterministic structured parser proves the value boundary;
- include metadata only;
- require the user to create or select a safe source excerpt outside the denied value.

The manifest records every transformation and digest.

## 7.4 Untrusted instructions

Text in source, comments, documentation, issue templates, generated files, prompts, Agent files, or Tool results is untrusted data unless it is selected through the accepted active Project instruction authority.

Untrusted content cannot:

- change the objective or criteria;
- add Tools;
- grant authority;
- change disclosure policy;
- request secrets;
- widen paths;
- select a provider or model;
- authorize a Patch or Command;
- mark Evidence passing;
- accept completion.

# 8. Tool projection

## 8.1 Tool set

The complete first-month model-facing Tool set is:

```text
repo.search
repo.read
artifact.read
change.propose
```

There is no catalog-discovery Tool.

## 8.2 Step eligibility

| Workflow step | Tools |
| --- | --- |
| `investigation` | `repo.search`, `repo.read`, `artifact.read`, `change.propose` |
| `proposal` | `repo.search`, `repo.read`, `artifact.read`, `change.propose` |
| `approval` | none |
| `application` | none |
| `verification` | `artifact.read` only when a bounded current result must be summarized |
| `acceptance` | none |
| `reconciliation` | none in the first-month model boundary |

P0-W23 owns Patch validation and application. `change.propose` creates only a proposal Artifact and normalized proposal request. It has no mutation authority.

## 8.3 Common Tool rules

Every Tool call includes:

```text
tool_call_id
invocation_id
tool_name
arguments
arguments_digest
authority_reference
repository_state_binding | null
limit_snapshot
```

Every result includes:

```text
tool_call_id
status
result_reference | inline_result
result_digest
repository_state_binding | null
completeness
warnings
continuation | null
```

Rules:

- Tool arguments must validate against the selected fixed schema;
- Tool availability cannot grant authority;
- unknown Tool names fail the invocation;
- maximum Tool calls per invocation is 12;
- maximum provider turns is 8;
- only one Tool call is executed at a time in the first contract;
- no parallel Tool calls;
- a Tool cannot call another Tool;
- a Tool cannot change the Tool projection;
- a stale Repository binding returns a structured stale result;
- Tool result content passes the same secret and disclosure rules before provider return.

## 8.4 `repo.search`

Purpose: find bounded literal matches in eligible active-Repository text.

It cannot search the whole machine, reference repositories, `$KILN_HOME`, binary files, denied paths, or provider-side data.

## 8.5 `repo.read`

Purpose: read one bounded active-Repository text range with exact state binding.

It cannot follow symlinks, read arbitrary absolute paths, or disclose content without accepted policy.

## 8.6 `artifact.read`

Purpose: read one bounded excerpt from a Kiln-owned Artifact already authorized for this Run and provider destination.

It cannot enumerate all Artifacts, read secret-classified Artifacts, change retention, or make Artifact content Evidence.

Maximum excerpt is 16,384 bytes.

## 8.7 `change.propose`

Purpose: return one normalized proposed change for later deterministic validation under P0-W23.

The first contract accepts:

- summary;
- rationale;
- affected relative paths;
- proposed text Patch payload or Artifact reference;
- assumptions and unknowns;
- expected criteria impact.

It cannot:

- apply source changes;
- approve its proposal;
- run a Command;
- change criteria;
- claim verification or acceptance.

P0-W23 owns the exact Patch representation, digest, limits, base binding, and proposal acceptance rules. Until P0-W23 integrates, `change.propose` remains a planning interface and does not settle Patch semantics.

# 9. Large results and continuation

A Tool result stays inline only when it is within the accepted result limit.

Larger content becomes an immutable Artifact with:

- content digest;
- byte count;
- media type;
- sensitivity;
- trust;
- Repository state binding when applicable;
- completeness;
- creator operation;
- bounded excerpt;
- continuation method.

The provider receives at most:

- a 16,384-byte Artifact excerpt;
- digest and metadata;
- a continuation token valid only for the same invocation, Artifact, disclosure decision, and state.

Continuation does not widen the total package, Tool-call, turn, elapsed, or disclosure limits.

# 10. Persistence and retention boundary

Persist:

- normalized invocation request;
- provider profile and model;
- Context manifest and package digest;
- Tool projection and digest;
- disclosure decision references;
- operation intent and terminal or unknown result reference through P0-W21;
- normalized Tool requests and results;
- visible final response Artifact;
- normalized usage;
- warnings, failures, and unknowns;
- result digest and provider request ID when present.

Do not persist by default:

- provider credential value;
- complete HTTP headers;
- complete serialized request body;
- raw streaming frames;
- provider-native hidden reasoning or thinking;
- duplicate source excerpts when exact Repository state and item digests can recover them;
- provider-side logs or retention claims;
- full transient provider conversation.

A diagnostic mode that retains raw provider payload is outside the first contract because it can capture source, secrets, and reasoning.

# 11. Failure matrix

| Failure | Result | Dispatch or effect classification | Next action |
| --- | --- | --- | --- |
| missing credential | `PROVIDER_CREDENTIAL_MISSING` | not dispatched | configure opaque reference |
| stale Context | `STALE_CONTEXT` | not dispatched | rebuild package |
| disclosure denied | `DISCLOSURE_DENIED` | not dispatched | change policy or omit item |
| secret match | `SECRET_BLOCKED` | not dispatched | omit or provide safe source |
| invalid path | `PATH_DENIED` | no Tool effect | correct request |
| binary or invalid UTF-8 | `CONTENT_UNSUPPORTED` | no content disclosed | use another source |
| package limit exceeded | `CONTEXT_LIMIT_BLOCKED` | not dispatched | deterministic reduction |
| unknown Tool | `TOOL_NOT_ALLOWED` | provider result invalid | fail invocation |
| invalid Tool arguments | `TOOL_ARGUMENTS_INVALID` | Tool not executed | fail invocation |
| Tool result stale | `STALE_SOURCE` | no content returned | rebuild or reread |
| provider HTTP error with known response | `PROVIDER_FAILED` | dispatched; known failure response | explicit new action only |
| rate limit | `PROVIDER_RATE_LIMITED` | dispatched or rejected by provider; known response | explicit later action |
| timeout before dispatch | `PROVIDER_LOCAL_TIMEOUT` | not dispatched | explicit retry allowed |
| timeout or connection loss after dispatch | operation `unknown` | uncertain hosted effect | reconcile; no automatic retry |
| malformed terminal response | `PROVIDER_MALFORMED_RESULT` when terminal failure is known | dispatched; known invalid result | inspect and start new action |
| stream ends without terminal classification | operation `unknown` | uncertain result | reconcile |
| cancel before dispatch | `canceled_before_dispatch` | no hosted effect | return to workflow |
| cancel after dispatch without terminal result | operation `unknown` | uncertain hosted effect | reconcile |

# 12. Security invariants

The first-month implementation must prove:

1. Only MiniMax is a real provider destination.
2. No fallback occurs.
3. Credentials never enter durable or user-visible records.
4. Every disclosed item has a current disclosure decision.
5. Context cannot grant authority.
6. Repository paths cannot escape the canonical root.
7. Symlink, special-file, binary, invalid-encoding, and oversized content is denied.
8. Mandatory secret paths cannot be overridden.
9. High-confidence secret matches block the whole excerpt by default.
10. Exactly four or fewer Tool schemas enter a request.
11. Unused Tool schemas are absent.
12. No Tool can mutate source or run a Command.
13. Provider-native reasoning is not persisted or treated as Evidence.
14. A dispatched request is not retried automatically.
15. An uncertain provider effect becomes unknown under the P0-W21 boundary.

# 13. Implementation boundary

After later Prompt 8 authorization, P0-W22 makes these units safe to implement:

- provider behaviour and MiniMax adapter;
- deterministic fake provider;
- provider request and result mapping;
- streaming normalization;
- sealed Context manifest and package builder;
- fixed Tool projection;
- active-Repository observation, literal search, and bounded read;
- Artifact excerpt read;
- disclosure decisions and provider-bound package checks;
- mandatory path and secret screening;
- large-result externalization and continuation;
- provider boundary contract fixtures.

P0-W22 does not unlock:

- Patch validation, Approval, application, or rollback;
- registered Command execution;
- criterion Evidence, completion, Receipt, or acceptance;
- full CLI implementation;
- Child Runs or later scope.

# 14. Prompt 3 dispositions

P0-W22 changes the planning direction for:

- IU-08: one MiniMax OpenAI-compatible adapter and one deterministic fake;
- IU-09: one explicit sealed package, fixed item classes, limits, and four-Tool projection;
- IU-13: provider and Tool large results become Artifact references, while exact storage is owned by P0-W24;
- IU-31: no general Capability broker or provider router is justified;
- `kiln-context.schema.json`: reduce compiler, retrieval-provider, Skill, semantic, and observability fields;
- `kiln-execution.schema.json`: reduce Agent catalog, Skill, Terminal, broad Capability, and fallback fields;
- `kiln-capability.schema.json`: keep outside the first-month required subset except fixed Tool-result ideas consumed directly;
- `kiln-core.schema.json`: provider and Context references must not require broad Agent or Client state.

# 15. Candidate Prompt 6 scaffolding

Prompt 6 can evaluate:

- provider behaviour and fake script contract;
- normalized invocation request, event, result, and usage types;
- Context item, manifest, package, and digest types;
- fixed Tool-projection and step-eligibility validators;
- Repository observation, normalized path, search, read, continuation, and stale-source result types;
- disclosure policy and decision types;
- secret-screen result and mandatory path fixtures;
- malformed provider, timeout, cancel, no-fallback, path-escape, symlink, binary, secret-canary, stale-Context, and oversized-result fixtures.

Prompt 6 must not add a provider router, general Context compiler, runtime Skill system, code index, protocol adapter, Patch application, Command execution, or fake passing product gate.

# 16. External evidence

Current official sources reviewed on 2026-07-28:

- MiniMax API overview and current text models: `https://platform.minimax.io/docs/api-reference/api-overview`
- MiniMax OpenAI-compatible API: `https://platform.minimax.io/docs/api-reference/text-openai-api`
- MiniMax OpenAI-compatible chat endpoint: `https://platform.minimax.io/docs/api-reference/text-chat-openai`
- MiniMax API credential guidance: `https://platform.minimax.io/docs/faq/about-apis`

The official documentation supports the selected endpoint, current model identifier, text and Tool-call request fields, streaming, usage, and credential boundary. It does not establish provider-side deletion, retention, or a server-side cancellation guarantee. Kiln therefore records those properties as unknown and uses conservative local behavior.

# 17. Completion gate

P0-W22 passes only when:

- OD-01 remains unchanged and explicit;
- one endpoint, model, request, stream, result, usage, timeout, cancellation, malformed-result, and retry contract exists;
- one deterministic fake contract covers required success and failure paths;
- one ordered Context package and manifest has exact fields, digests, limits, inspection, staleness, and exclusions;
- all remotely disclosed items require current decisions;
- exact Repository root, path, ignore, symlink, file, encoding, size, search, read, and fingerprint rules exist;
- exactly four possible Tools exist and workflow steps omit unused schemas;
- secret values and denied source cannot enter provider Context;
- provider-native reasoning and complete raw payloads are excluded from durable state;
- no lifecycle, journal, Patch, Command, Evidence, completion, CLI, Child, or deferred-system authority is introduced;
- the post-P0-W21 reconciliation confirms this document consumes but does not redefine lifecycle and persistence;
- the exact final planning-only head passes Repository validation.

Passing P0-W22 does not issue build authorization.
