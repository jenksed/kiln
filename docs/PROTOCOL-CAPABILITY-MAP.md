# Protocol capability map

- **Status:** Accepted planning baseline
- **Date:** 2026-07-28
- **Scope:** Protocol and standards positions for Kiln

Kiln does not exist to implement protocols. Kiln uses protocols when they improve repository throughput, interoperability, recovery, security, or evidence quality.

A protocol must not own Kiln's product semantics. Kiln's native Session, Run, Event, Capability, Artifact, Permission, Change set, and Evidence concepts remain authoritative.

## Priority vocabulary

- **Foundational:** Kiln's architecture must support this capability. Implementation can still follow the proof-ordered roadmap.
- **Expansion:** valuable after the first useful coding loop or when a real integration requires it.
- **Watch:** preserve an adapter seam and monitor the standard. Do not make it a dependency.
- **Reject:** do not adopt the stated role or integration pattern.

## Communication vocabulary

- **Inbound:** an external client or producer calls Kiln or sends Kiln data.
- **Outbound:** Kiln calls an external service, runtime, server, or tool.
- **Bidirectional:** both sides initiate meaningful messages or state changes.
- **Internal:** no public wire contract is required.

## Protocol capability summary

| Protocol or standard | Priority | Direction | Kiln's role | Internal mapping | First useful implementation |
|---|---|---:|---|---|---|
| ACP | Foundational | Bidirectional | Coding agent endpoint for editor clients | Session, Run, Terminal, Change set, Permission, Event | One local editor attaches to one existing Kiln Session and receives ordered Run events |
| AG-UI | Expansion | Bidirectional | Agent backend for user-facing applications | Run event, shared state, interrupt, frontend action | LiveView or web client consumes the same event projection as the CLI and ACP |
| AHP | Watch | Bidirectional | Native authoritative host, not an AHP-dependent runtime | authoritative state, client, channel, action, snapshot | Document compatible concepts and test reconnect semantics without implementing AHP |
| MCP client | Foundational | Outbound | Host and client of brokered MCP servers | Capability, Resource, Prompt, Tool call, Artifact, long-running operation | Connect one local MCP server through explicit allowlisted capabilities |
| MCP server | Expansion | Inbound | Restricted provider of selected Kiln capabilities | Capability, Resource, Prompt, Tool call, Artifact, long-running operation | Read-only Session and evidence resources after authentication and policy exist |
| A2A | Watch | Bidirectional | Client or server for independent remote agents | remote agent, task, message, artifact | No implementation until an external-agent interoperability case exists |
| OpenAPI | Expansion | Primarily outbound | Typed client for narrow HTTP services; optional headless server description | Service, operation, input schema, output schema, credential policy | Import one OpenAPI operation as a brokered capability |
| JSON Schema | Foundational | Internal and bidirectional | Schema dialect for contracts and validation | Command payload, Event payload, capability input/output, artifact metadata | Validate extension and capability declarations with a pinned dialect |
| LSP | Foundational | Outbound | Client of language servers behind a normalized semantic service | Symbol, Location, Diagnostic, Edit | Definitions, references, diagnostics, and workspace edits for one language |
| DAP | Expansion | Outbound | Client of debug adapters | Debug session, Frame, Scope, Variable, Evaluation | Launch or attach, stop at breakpoint, inspect frames and variables, terminate safely |
| Tree-sitter | Foundational | Internal | Structural parser and change detector | Syntax tree, node, range, query capture, structural fingerprint | Parse changed files for supported languages and expose bounded structural summaries |
| SCIP or equivalent | Expansion | Inbound and internal | Consumer of persistent semantic indexes; optional producer | Symbol, occurrence, relationship, document, index provenance | Import an existing index and answer definitions and references without running a live server |
| BSP | Watch | Outbound | Client of build servers where project ecosystems justify it | Build target, compile task, test task, diagnostic, artifact | No implementation until direct command execution cannot provide reliable build semantics |
| Agent Skills | Foundational | Inbound package and internal loading | Skill host, validator, policy mediator, and test runner | Skill, activation description, capability declaration, permission, provenance, test, resource | Discover `SKILL.md`, show metadata, load body only on activation, and require declared capabilities |
| Dev Container Specification | Expansion | Inbound configuration and outbound execution | Consumer and launcher, not an editor clone | Workspace environment, mount, feature, command, secret reference | Detect `devcontainer.json` and offer an explicit contained execution profile |
| OCI image and runtime specifications | Expansion | Outbound | Runtime client and artifact consumer | Image digest, runtime bundle, process, mount, namespace, resource limit | Launch an allowlisted command in a pinned image with recorded digest and termination state |
| Git worktrees | Foundational | Internal through Git | Workspace isolation mechanism | Repository, branch, worktree, base revision, Change set | Detect worktree identity and create one isolated task worktree with explicit cleanup |
| WASI | Watch | Outbound runtime | Experimental component runtime | Component, capability import, filesystem scope, network scope, execution result | One non-critical read-only experiment after the subprocess extension boundary is proven |
| WIT | Watch | Bidirectional contract | Experimental plugin interface description | Interface, world, import, export, typed resource | Generate and validate bindings for one experimental component only |
| OpenTelemetry | Foundational | Internal instrumentation | Producer of operational telemetry about Kiln | trace, span, event, metric | Trace Session command handling, model request, tool execution, and persistence latency |
| OTLP | Expansion | Outbound | Optional telemetry exporter | telemetry batch, resource attributes, trace/span identity | Export traces to a local collector without making export required for Kiln operation |
| SARIF | Expansion | Inbound; optional outbound | Importer of static-analysis evidence | analysis invocation, rule, finding, location | Ingest one SARIF file into normalized findings bound to repository state |
| JUnit-compatible reports | Foundational | Inbound | Importer of test evidence | test run, suite, case, outcome, duration, failure, attachment | Ingest common JUnit XML and bind results to command, commit, and fingerprint |
| Durable artifact references | Foundational | Internal and outward-facing | Owner of stable references to files and generated outputs | Artifact identity, content digest, media type, location, producer, repository binding | Persist artifact metadata and digest while allowing content to remain in the filesystem |
| Evidence receipts | Foundational | Internal and outward-facing | Native evidence authority | invocation, subject, inputs, result, timestamps, environment, freshness, artifact references | Issue a receipt for a command or verification result and invalidate it after relevant mutation |
| in-toto attestations | Expansion | Outbound; optional inbound verification | Exporter and verifier of selected evidence claims | subject, material, invocation, builder, result | Export one signed evidence receipt as an in-toto statement when publication requires it |
| SLSA provenance | Expansion | Outbound | Producer for build and release provenance, not local session truth | subject, build definition, run details, builder, materials | Generate provenance for a reproducible Kiln-built release artifact |

## Required product positions

The following positions are accepted:

- ACP becomes Kiln's primary editor and coding-client interface.
- Kiln's internal event model exists before the ACP adapter.
- MCP client support is more important than MCP server support.
- MCP catalogs remain behind the capability broker.
- LSP is normalized into a narrow semantic interface.
- Tree-sitter is internal structural infrastructure, not a primary model-facing tool.
- DAP is high-value but not necessary for the first useful coding loop.
- AG-UI uses the same internal event stream as the CLI, TUI, LiveView, and ACP.
- AHP concepts may inform Kiln, but Kiln does not depend on an unstable protocol.
- A2A is reserved for independent external agents.
- Local child Runs use Kiln's native execution model, not A2A.
- OpenAPI can be better than MCP for narrow existing services.
- Agent Skills are first-class.
- OpenTelemetry observes Kiln itself.
- WASI and WIT remain future plugin-boundary experiments until justified.

## Client and user interfaces

### ACP

- **Priority:** Foundational.
- **Communication direction:** Bidirectional between an editor client and Kiln.
- **Kiln's role:** ACP agent endpoint. The editor is the ACP client.
- **Internal mapping:** ACP session to `Session`; prompt or operation to `Run`; terminal operations to `Terminal`; file operations to `Change set`; approval exchanges to `Permission`; streamed updates to ordered `Event` projections.
- **Adapter boundary:** `Kiln.Adapter.ACP` translates ACP messages into domain commands and queries. It subscribes to the event journal projection. It does not write persistence records directly.
- **Security implications:** Authenticate remote clients. Bind each client to allowed workspaces and Sessions. Route terminal, filesystem, network, and Git actions through the permission broker. Do not trust client-provided paths or terminal identifiers.
- **Context and token implications:** ACP should carry structured events, diffs, references, and bounded terminal output. It must not cause transcript replay to become the recovery mechanism. Clients request snapshots and event ranges instead of receiving unlimited history.
- **First useful implementation:** One local ACP client can attach to one existing Session, submit an instruction, receive text and tool progress, display permission requests, stream a terminal, and reconnect from a cursor.
- **Deferred features:** remote transport, multi-client editing, rich editor decorations, advanced plan objects, multiple simultaneous terminals, and client-specific custom methods.
- **Exit strategy:** Keep ACP IDs and version data in adapter metadata. Domain events remain independent. Replace the adapter if ACP changes incompatibly.
- **Acceptance criteria:** Adapter conformance tests prove ordered event delivery, cancellation, permission mediation, terminal cleanup, reconnect without duplicate effects, and unknown-version failure with a clear message.

### AG-UI

- **Priority:** Expansion.
- **Communication direction:** Bidirectional between Kiln and web, desktop, mobile, or embedded frontends.
- **Kiln's role:** Agent backend that emits Run events and receives interrupts or frontend actions.
- **Internal mapping:** AG-UI Run lifecycle to `Run event`; shared state to a query-derived projection; interrupt to an explicit Run command; frontend tool or action to a brokered `Capability` request.
- **Adapter boundary:** `Kiln.Adapter.AGUI` consumes the same event projection used by ACP and the TUI. AG-UI state snapshots are generated from native state and are never authoritative.
- **Security implications:** Treat frontend actions as untrusted input. Require authentication, origin controls, capability checks, bounded payloads, and protection against replay. Browser code never receives provider or service secrets.
- **Context and token implications:** Use snapshots and deltas for UI state. Do not feed all shared UI state to the model. The context engine selects only relevant, provenance-bearing fields.
- **First useful implementation:** LiveView or a small web client displays a Session, Run stream, active execution, permission request, diff, and interruption control from the native event stream.
- **Deferred features:** generative UI, multimodal streaming, client-side tools, collaborative shared-state writes, and protocol-specific sub-agent visualization.
- **Exit strategy:** Frontends can fall back to Kiln's headless API or native event stream. AG-UI event names remain adapter concerns.
- **Acceptance criteria:** ACP, CLI/TUI, and AG-UI projections show equivalent Run state from the same event sequence, and reconnect produces an equivalent snapshot.

### AHP

- **Priority:** Watch.
- **Communication direction:** Conceptually bidirectional and multi-client.
- **Kiln's role:** Kiln already owns authoritative state. A future AHP adapter would expose that state, not replace it.
- **Internal mapping:** AHP authoritative state to Session snapshot; client to authenticated client attachment; channel to Event subscription; action to domain command; snapshot to versioned query result.
- **Adapter boundary:** No runtime dependency. Maintain a design note mapping AHP reducers, immutable state, actions, snapshots, and reconciliation to Kiln concepts.
- **Security implications:** Multi-client authority increases replay, conflict, impersonation, and approval ambiguity. Each action needs client identity, authorization, idempotency, and audit linkage.
- **Context and token implications:** Synchronized state helps avoid transcript reconstruction, but complete state must not become model context by default.
- **First useful implementation:** None. Test Kiln's own multi-client reconnect, snapshot, action-idempotency, and event-cursor semantics.
- **Deferred features:** AHP wire protocol, reducer compatibility, cross-client action reconciliation, and external client conformance.
- **Exit strategy:** Because Kiln stores native events and snapshots, an AHP adapter can be added or removed without migration of core state.
- **Acceptance criteria:** Kiln can demonstrate authoritative state, ordered actions, resumable channels, snapshots, and duplicate-action rejection independently of AHP.

## Capability and agent interfaces

### MCP client support

- **Priority:** Foundational.
- **Communication direction:** Outbound from Kiln to MCP servers, with bidirectional notifications where supported.
- **Kiln's role:** MCP host and client. The capability broker remains between discovery and use.
- **Internal mapping:** MCP tool to `Capability`; resource to `Resource` or `Artifact reference`; prompt to a user-selectable procedural template; tool call to `Tool call`; returned content to `Artifact` or bounded result; task or progress flow to `long-running operation`.
- **Adapter boundary:** `Kiln.Adapter.MCP.Client` owns protocol negotiation and transport. It registers normalized candidates with the capability broker. The broker decides visibility and authority.
- **Security implications:** Server metadata is untrusted. Tool descriptions can contain prompt injection. Require server trust records, explicit host and executable policy, schema validation, timeouts, cancellation, output limits, secret isolation, and per-capability permission mapping.
- **Context and token implications:** Never inject an entire MCP catalog into every model request. Select capabilities deterministically by task, skill, policy, and explicit user choice. Summarize large resource results and retain durable references.
- **First useful implementation:** One local stdio MCP server, explicit configuration, pinned command, allowlisted tools, schema validation, progress, cancellation, bounded output, and complete audit events.
- **Deferred features:** remote HTTP transports, OAuth flows, dynamic server installation, prompts, resource subscriptions, elicitation, sampling, server registries, and broad task support.
- **Exit strategy:** Normalize tools and results. Store protocol version and raw server identity as adapter metadata. Disable incompatible servers without changing Sessions.
- **Acceptance criteria:** No discovered MCP tool is model-visible or invokable until broker policy permits it; cancellation and server crash produce accurate terminal states; catalog size does not increase prompt size unless selected.

### Optional MCP server support

- **Priority:** Expansion.
- **Communication direction:** Inbound from external MCP hosts.
- **Kiln's role:** Restricted MCP server exposing selected read or action capabilities.
- **Internal mapping:** Kiln queries can become resources; explicit workflows can become prompts; narrowly authorized commands can become tools; evidence and artifacts remain native objects referenced by MCP content.
- **Adapter boundary:** A separate server adapter with an allowlist. It cannot enumerate or expose all domain commands automatically.
- **Security implications:** Requires authentication, tenancy or user binding, workspace scoping, rate limits, replay protection, permission propagation, and strong separation from provider credentials.
- **Context and token implications:** Return concise structured summaries and artifact links. Do not export full journals or repository contents by default.
- **First useful implementation:** Authenticated read-only resources for Session snapshot, active Run status, and evidence receipt lookup.
- **Deferred features:** mutating tools, remote installation, hosted access, prompt exposure, and third-party automation.
- **Exit strategy:** Remove the server adapter without affecting the internal capability broker or MCP client.
- **Acceptance criteria:** The server exposes only an explicit allowlist, applies the same authorization rules as native clients, and never converts remote discovery into ambient authority.

### A2A

- **Priority:** Watch. **Reject** for local child Runs.
- **Communication direction:** Bidirectional with independent external agents.
- **Kiln's role:** Future A2A client or server at a remote trust boundary.
- **Internal mapping:** A2A agent to `remote agent`; task to remote task linked to a Kiln Run; message to structured remote message; artifact to durable Artifact reference.
- **Adapter boundary:** `Kiln.Adapter.A2A` must be outside the local Run supervisor. It translates remote task state into events and evidence without pretending Kiln owns the remote process.
- **Security implications:** Agent cards and remote claims are untrusted. Require identity, endpoint policy, credential isolation, signed or verifiable artifacts when needed, strict content limits, and no automatic delegation chains.
- **Context and token implications:** Remote history and agent metadata can be large. Import only task-relevant messages and artifact references. Summaries must retain provenance.
- **First useful implementation:** None until Kiln must delegate to or accept work from an independently deployed agent.
- **Deferred features:** discovery, streaming, push notifications, agent cards, remote task resumption, and artifact negotiation.
- **Exit strategy:** Represent remote work through native remote-task and Artifact records. Replace the A2A adapter if task semantics change.
- **Acceptance criteria:** Local child Runs do not use A2A. A future remote integration must preserve remote ownership, cancellation uncertainty, and evidence provenance.

### OpenAPI

- **Priority:** Expansion.
- **Communication direction:** Primarily outbound to existing HTTP services. Inbound only for a future headless Kiln API description.
- **Kiln's role:** Typed client generator or dynamic operation importer behind the capability broker.
- **Internal mapping:** operation to `Capability`; request schema to capability input; response schema to typed result or Artifact; security scheme to credential policy; server to allowed network origin.
- **Adapter boundary:** OpenAPI import produces a reviewed capability manifest. It does not expose every operation automatically.
- **Security implications:** Enforce allowed servers, methods, paths, redirect rules, credentials, payload limits, and response content types. Treat descriptions and examples as untrusted documentation.
- **Context and token implications:** A narrow operation contract is often smaller and clearer than an MCP catalog. Select only relevant operation schemas for model context.
- **First useful implementation:** Import one operation from a pinned OpenAPI document, validate input and output, and invoke it through network and secret permissions.
- **Deferred features:** automatic SDK generation, callbacks, webhooks, broad API ingestion, and server generation.
- **Exit strategy:** Persist a normalized operation contract and source document digest. Regenerate or replace the importer when OpenAPI versions change.
- **Acceptance criteria:** Imported operations require explicit approval, use pinned servers and schemas, and cannot bypass network or secret capabilities.

### JSON Schema

- **Priority:** Foundational.
- **Communication direction:** Internal validation and external contract exchange.
- **Kiln's role:** Consumer and producer of schemas with one explicitly pinned dialect per contract family.
- **Internal mapping:** schemas describe command payloads, Event payloads, capability inputs and outputs, adapter messages, Skill declarations, Artifact metadata, and evidence exports.
- **Adapter boundary:** Domain structs remain native. Schemas validate wire and package boundaries.
- **Security implications:** Bound recursion, reference resolution, regex cost, document size, and remote schema fetching. Disable implicit network resolution.
- **Context and token implications:** Schemas can be verbose. Provide models with selected properties and concise capability descriptions, not full recursive definitions unless required.
- **First useful implementation:** Pin JSON Schema 2020-12 for Kiln-owned manifests and validate capability and extension declarations.
- **Deferred features:** custom vocabularies, automatic form generation, and schema-to-code generation across SDKs.
- **Exit strategy:** Store schema URI and version with documents. Migrate at adapters and manifests, not in event semantics.
- **Acceptance criteria:** Invalid manifests fail before registration; no schema is fetched from the network without explicit policy; compatibility tests cover additive and breaking changes.

## Code and build intelligence

### LSP

- **Priority:** Foundational.
- **Communication direction:** Outbound from Kiln to language servers.
- **Kiln's role:** LSP client behind a narrow semantic service.
- **Internal mapping:** LSP symbol to `Symbol`; URI and range to `Location`; diagnostic to `Diagnostic`; workspace edit to proposed `Edit` or Change set.
- **Adapter boundary:** `Kiln.Semantics` offers operations such as definitions, references, symbols, diagnostics, hover summary, rename preview, and edits. Language-specific LSP details do not enter model tools.
- **Security implications:** Language servers are repository-adjacent executables. Supervise them, pin or resolve them through project policy, limit workspace roots, mediate network access, and validate edits before applying them.
- **Context and token implications:** Normalize and rank results. Return locations and concise semantic summaries. Do not expose the full LSP method set or dump all diagnostics into context.
- **First useful implementation:** One language server supports definition, references, diagnostics, document symbols, and validated workspace edits.
- **Deferred features:** completion, semantic tokens, code lens, inlay hints, custom methods, multi-root workspaces, and server installation.
- **Exit strategy:** Native Symbol, Location, Diagnostic, and Edit records allow replacement by compiler APIs, indexes, or other semantic providers.
- **Acceptance criteria:** The same semantic query has a stable Kiln result shape across languages; edits are previewed, permission-checked, and repository-bound.

### DAP

- **Priority:** Expansion.
- **Communication direction:** Outbound from Kiln to debug adapters.
- **Kiln's role:** Debug client and lifecycle supervisor.
- **Internal mapping:** adapter session to `Debug session`; stack frame to `Frame`; scope to `Scope`; variable to `Variable`; evaluate request and result to `Evaluation`.
- **Adapter boundary:** `Kiln.Debug` exposes launch or attach, pause, continue, step, inspect, evaluate, and terminate. Raw adapter messages remain private.
- **Security implications:** Debugging can execute code, attach to processes, read memory, and expose secrets. Require explicit permissions, target restrictions, evaluation controls, and reliable cleanup.
- **Context and token implications:** Stack and variable graphs can explode. Use depth, count, size, and value redaction limits. Models receive selected frames and variables.
- **First useful implementation:** Launch one test target, stop at a breakpoint, inspect top frames and bounded variables, then terminate and record the result.
- **Deferred features:** remote attach, reverse debugging, data breakpoints, memory access, disassembly, and multi-process debugging.
- **Exit strategy:** Preserve normalized debug evidence and events. Replace adapter-specific integrations without changing Runs.
- **Acceptance criteria:** Debug sessions cannot outlive their owning Run without explicit policy; evaluation is permissioned and bounded; termination state is accurate.

### Tree-sitter

- **Priority:** Foundational internal infrastructure. **Reject** as a primary raw model-facing tool.
- **Communication direction:** Internal.
- **Kiln's role:** Parser host, structural indexer, and mutation analyzer.
- **Internal mapping:** concrete syntax tree to structural representation; node and range to source structure; query captures to symbols or regions; parse version and grammar digest to provenance.
- **Adapter boundary:** `Kiln.Structure` returns bounded language-neutral facts such as declarations, imports, tests, call-like relationships, and changed structural regions.
- **Security implications:** Grammars and native bindings are executable dependencies. Pin versions and digests, isolate crashes, bound parse time and file size, and handle malformed input.
- **Context and token implications:** Structural summaries and targeted ranges reduce repeated file reads. Raw trees are too verbose and grammar-specific for routine model context.
- **First useful implementation:** Parse changed files in a small language set, detect declaration boundaries, and produce structural fingerprints used for context selection and evidence invalidation.
- **Deferred features:** whole-repository graph construction, complex cross-language queries, automatic refactoring, and model-authored Tree-sitter queries.
- **Exit strategy:** Store derived facts with parser and grammar provenance so they can be rebuilt by another parser.
- **Acceptance criteria:** Parse failures degrade to known unknowns; no completion claim depends on stale structural facts; model tools return bounded normalized results.

### SCIP or equivalent persistent semantic index

- **Priority:** Expansion.
- **Communication direction:** Primarily inbound index ingestion; optional export.
- **Kiln's role:** Consumer of persistent semantic data and owner of freshness policy.
- **Internal mapping:** SCIP symbol to `Symbol`; occurrence to `Location` plus role; relationship to semantic edge; document to indexed file; metadata to index provenance.
- **Adapter boundary:** `Kiln.SemanticIndex` accepts SCIP or another provider and exposes the same normalized semantic interface as LSP where possible.
- **Security implications:** Indexes can be stale, malicious, or path-confused. Validate repository identity, commit, paths, size, and producer provenance.
- **Context and token implications:** Persistent indexes can answer navigation questions with fewer tool calls and less source text. Results still require ranking and freshness disclosure.
- **First useful implementation:** Import a project-generated SCIP index bound to a commit and answer definition and reference queries.
- **Deferred features:** automatic index production for many languages, incremental updates, global cross-project graph, and index sharing.
- **Exit strategy:** The internal semantic interface is provider-neutral. Delete and rebuild indexes when formats change.
- **Acceptance criteria:** Every result reports source index, commit, and freshness; stale indexes never silently override current LSP or repository observations.

### BSP

- **Priority:** Watch.
- **Communication direction:** Outbound from Kiln to build servers.
- **Kiln's role:** Possible client for ecosystems where build targets and diagnostics cannot be recovered reliably from commands.
- **Internal mapping:** build target to target record; compile or test request to supervised operation; diagnostic to `Diagnostic`; output to Artifact; task progress to Run events.
- **Adapter boundary:** A future `Kiln.Build` service can accept BSP as one provider. Direct project commands remain valid providers.
- **Security implications:** Build servers execute project code and may keep long-lived state. Apply process, network, filesystem, and secret permissions.
- **Context and token implications:** Structured targets can reduce shell exploration. Large build graphs must be queried, not inserted into context.
- **First useful implementation:** None until a supported repository proves that BSP provides material value over supervised commands and structured reports.
- **Deferred features:** target discovery, compile, test, run, clean-cache, and multi-build-server routing.
- **Exit strategy:** Keep build targets and results normalized. Fall back to command-based execution.
- **Acceptance criteria:** Adoption requires a measured workflow improvement and no loss of accurate command, artifact, or termination evidence.

## Skills and procedural knowledge

### Agent Skills-compatible packages

- **Priority:** Foundational.
- **Communication direction:** Inbound package discovery and internal activation.
- **Kiln's role:** Skill host, validator, lazy loader, capability policy mediator, provenance recorder, and test runner.
- **Internal mapping:** Skill directory to `Skill`; frontmatter description to activation metadata; body to procedural context; scripts to deterministic capability implementations; references to lazy resources; declared permissions to capability requests; tests to Skill verification evidence.
- **Adapter boundary:** Compatibility begins with the Agent Skills `SKILL.md` structure. Kiln-specific declarations use namespaced metadata or companion manifests and must not corrupt portable content.
- **Security implications:** Skills are untrusted code and instructions. Separate reading from execution. Record source and digest. Require explicit permissions for scripts, network, secrets, writes, and external processes. Never auto-run installation instructions.
- **Context and token implications:** Discover from name and description. Load the body only when activated. Load bundled references only when needed. Prefer deterministic scripts for repetitive work and return concise results.
- **First useful implementation:** Discover repository and user Skills, validate metadata, display provenance, activate by explicit choice or deterministic match, load `SKILL.md` lazily, and mediate declared capabilities.
- **Deferred features:** registries, automatic installation, dependency resolution, cross-skill composition, remote Skills, reputation, signatures, and generated Skills.
- **Exit strategy:** Preserve standard `SKILL.md` content and keep Kiln additions optional and namespaced. A Skill remains usable by another compatible host.
- **Acceptance criteria:** Discovery does not load full Skill bodies; activation records the Skill digest and source; undeclared privileged actions fail; bundled scripts and tests run under the same capability and evidence rules as other tools.

#### Required Skill features

- **Lazy loading:** mandatory. Metadata is cheap; full instructions and references load only when selected.
- **Capability declarations:** mandatory for executable or privileged behavior.
- **Permissions:** resolved by the capability broker, not granted by the Skill.
- **Provenance:** source path or URI, content digest, version or revision, author or publisher when known, and load time.
- **Tests:** Skills can bundle deterministic fixtures and acceptance tests. Test results become evidence.
- **Bundled deterministic scripts:** preferred for exact transformations, validation, or data extraction. Scripts remain supervised tools.
- **Bundled reference files:** addressed by path and digest and loaded on demand.

## Execution and isolation standards

### Dev Container Specification

- **Priority:** Expansion.
- **Communication direction:** Inbound configuration, outbound build and launch.
- **Kiln's role:** Consumer of repository-defined development environment metadata.
- **Internal mapping:** container configuration to workspace execution profile; mounts to filesystem capabilities; features to environment dependencies; lifecycle commands to supervised operations; secrets to named secret references.
- **Adapter boundary:** A dev-container adapter resolves configuration into a reviewable execution plan. Kiln does not inherit editor-specific settings as runtime truth.
- **Security implications:** Dockerfiles, features, lifecycle hooks, mounts, and forwarded sockets can grant broad host authority. Require preview, trust policy, restricted mounts, secret controls, image pinning, and clear containment claims.
- **Context and token implications:** Environment metadata can reduce setup exploration. Provide models with a concise resolved profile, not the full build log or configuration unless needed.
- **First useful implementation:** Detect and parse `devcontainer.json`, show the resolved image or build source and mounts, and offer explicit launch through an available OCI-compatible engine.
- **Deferred features:** features marketplace, compose topologies, editor customizations, port forwarding, and automatic rebuilds.
- **Exit strategy:** Convert configuration into a native execution profile. Other environment providers can produce the same profile.
- **Acceptance criteria:** Kiln shows all host mounts, sockets, secrets, network assumptions, lifecycle commands, and image identifiers before launch.

### OCI images and runtimes

- **Priority:** Expansion.
- **Communication direction:** Outbound to image stores and container runtimes.
- **Kiln's role:** Runtime client, image consumer, and evidence recorder.
- **Internal mapping:** image manifest and digest to execution environment Artifact; runtime bundle to contained process specification; lifecycle state to supervised execution; mounts and namespaces to capabilities.
- **Adapter boundary:** `Kiln.Execution.Container` implements the same execution contract as native subprocess execution and reports stronger or weaker guarantees explicitly.
- **Security implications:** Containers are not a universal sandbox. Rootless execution, mount restrictions, capability drops, seccomp or platform controls, network policy, resource limits, and daemon socket exposure matter.
- **Context and token implications:** Models should see the resolved environment identity, digest, and relevant limits, not image manifests or layer metadata.
- **First useful implementation:** Execute an allowlisted command in a pinned image with repository mount policy, no implicit secrets, cancellation, timeout, resource limits where available, and digest-bound evidence.
- **Deferred features:** image building, registries, signatures, multi-platform resolution, snapshotters, and remote runtimes.
- **Exit strategy:** The native execution contract allows Podman, Docker, containerd, or another OCI-compatible runtime to replace one another.
- **Acceptance criteria:** Evidence records image digest, runtime, mounts, network mode, command, exit status, and containment limitations.

### Git worktrees

- **Priority:** Foundational.
- **Communication direction:** Internal through Git commands.
- **Kiln's role:** Workspace allocator and lifecycle owner for isolated Runs.
- **Internal mapping:** repository plus revision to workspace; worktree path to workspace identity; branch to change lineage; diff to Change set; cleanup state to workspace lifecycle.
- **Adapter boundary:** `Kiln.Workspaces` owns creation, lookup, lease, status, and cleanup. Agents do not construct arbitrary `git worktree` commands.
- **Security implications:** Validate paths, repository identity, branch names, untracked files, submodules, hooks, and cleanup. Never delete an unknown or dirty worktree automatically.
- **Context and token implications:** Worktrees isolate changes without copying full repositories and make Run state easier to explain. Models receive current branch, base revision, and relevant diff summary.
- **First useful implementation:** Detect existing worktree identity and create one explicitly requested isolated worktree from a known base revision.
- **Deferred features:** automatic per-child-Run worktrees, pooling, parallel merge coordination, and garbage collection.
- **Exit strategy:** A workspace abstraction can later use clones, snapshots, or remote sandboxes.
- **Acceptance criteria:** Worktree creation and cleanup are idempotent; dirty state blocks destructive cleanup; each Change set remains bound to repository, base revision, branch, and path.

### WASI

- **Priority:** Watch.
- **Communication direction:** Outbound to a WebAssembly runtime.
- **Kiln's role:** Experimental host of capability-constrained components.
- **Internal mapping:** component execution to supervised operation; WASI imports to capability grants; filesystem and network handles to scoped permissions; output to Artifact or result.
- **Adapter boundary:** A future component runner implements Kiln's extension execution contract. WASI does not define the capability broker.
- **Security implications:** WASI can improve default-deny resource access, but runtime bugs, host functions, preopens, networking, clocks, and resource limits still require policy and accurate claims.
- **Context and token implications:** No special model context benefit. Components may reduce tool implementation risk when interfaces are narrow and deterministic.
- **First useful implementation:** One read-only, non-critical component experiment with explicit filesystem preopens and no network.
- **Deferred features:** networked components, persistent state, secrets, dynamic linking, registries, and production plugin requirements.
- **Exit strategy:** Keep the supervised extension contract transport-neutral. Remove the WASI runner without changing Skills or capabilities.
- **Acceptance criteria:** Adoption requires measured portability or isolation benefit over a subprocess and a documented supported WASI version.

### WIT

- **Priority:** Watch.
- **Communication direction:** Bidirectional typed interface description.
- **Kiln's role:** Experimental consumer and producer of component interfaces.
- **Internal mapping:** WIT world to extension contract; import to host capability; export to provided function; resource to typed opaque handle.
- **Adapter boundary:** WIT-generated bindings sit behind the native extension API.
- **Security implications:** Types do not grant authority. Every import maps to an explicit capability and resource lifetime.
- **Context and token implications:** Typed interfaces can produce concise tool declarations, but generated schemas still need selection and summarization.
- **First useful implementation:** Generate host and guest bindings for the single WASI experiment.
- **Deferred features:** public WIT SDK, version negotiation, component composition, and third-party distribution.
- **Exit strategy:** Maintain a protocol-neutral extension manifest and regenerate bindings from another IDL if required.
- **Acceptance criteria:** No WIT import exists without a capability mapping, and incompatible interface versions fail before execution.

## Evidence and telemetry standards

### OpenTelemetry

- **Priority:** Foundational.
- **Communication direction:** Internal instrumentation with optional export.
- **Kiln's role:** Producer of telemetry about its own runtime and adapters.
- **Internal mapping:** Session or major Run path to `trace`; model request, command, tool, persistence transaction, and adapter call to `span`; notable lifecycle facts to span `event`; counts and latency to `metric`.
- **Adapter boundary:** Instrumentation calls are behind a small Kiln telemetry API. Domain events remain durable truth; telemetry is operational observation.
- **Security implications:** Telemetry can leak prompts, source, paths, commands, secrets, and user data. Default to metadata, redaction, attribute allowlists, bounded values, and local-only export.
- **Context and token implications:** Telemetry is not model context by default. Selected aggregate facts can support debugging without loading full traces.
- **First useful implementation:** Trace domain command handling, SQLite operations, model requests, supervised executions, and adapter calls with stable identifiers and no prompt or source bodies.
- **Deferred features:** logs bridge, semantic conventions for agent systems, distributed traces, exemplars, and hosted backends.
- **Exit strategy:** Kiln runs with a no-op telemetry implementation. Instrumentation does not alter domain behavior.
- **Acceptance criteria:** Disabling telemetry changes no result; sensitive fields are absent by default; trace IDs can correlate operational spans with Session and Run IDs without replacing them.

### OTLP

- **Priority:** Expansion.
- **Communication direction:** Outbound to a collector.
- **Kiln's role:** Optional exporter.
- **Internal mapping:** OTel data batches and resource attributes remain telemetry records, separate from Event and Evidence storage.
- **Adapter boundary:** Exporter configuration is external to the domain runtime and can fail independently.
- **Security implications:** Require endpoint policy, TLS where remote, credential isolation, redaction before export, queue bounds, and failure backpressure limits.
- **Context and token implications:** No direct model context. A diagnostic Skill can query a backend through a separate brokered capability.
- **First useful implementation:** Export traces to a local OpenTelemetry Collector over one supported OTLP transport.
- **Deferred features:** metrics and logs export, remote SaaS defaults, tail sampling, and collector management.
- **Exit strategy:** Switch exporters or disable export without data migration in Kiln.
- **Acceptance criteria:** Collector absence does not fail Runs; queues are bounded; export failure is observable but not recursive.

### SARIF

- **Priority:** Expansion.
- **Communication direction:** Inbound from analyzers, with optional export.
- **Kiln's role:** Importer into the native finding and evidence model.
- **Internal mapping:** SARIF run to `analysis invocation`; rule to `rule`; result to `finding`; physical or logical location to `location`.
- **Adapter boundary:** Parser validates SARIF and emits normalized findings plus an Artifact reference to the original document.
- **Security implications:** SARIF can contain large embedded content, URIs, markdown, and external references. Bound size, sanitize rendering, restrict URI access, and validate paths.
- **Context and token implications:** Deduplicate, rank, and select findings. Preserve the report as an Artifact rather than putting it in model context.
- **First useful implementation:** Ingest SARIF 2.1.0 from one analyzer, map severity and locations, bind to repository fingerprint, and display unresolved findings.
- **Deferred features:** fixes, code flows, suppressions, taxonomies, baseline comparison, and export.
- **Exit strategy:** Native findings survive format changes. Reparse original artifacts with a newer adapter.
- **Acceptance criteria:** Findings report producer, rule, location, repository binding, and freshness; malformed or path-escaping results are rejected.

### JUnit-compatible and other structured test reports

- **Priority:** Foundational.
- **Communication direction:** Inbound from test runners.
- **Kiln's role:** Tolerant importer into the native test evidence model.
- **Internal mapping:** report to `test run`; suites to suite records; cases to case records; failure or error to outcome details; stdout, stderr, and attachments to bounded Artifacts.
- **Adapter boundary:** Format-specific parsers emit one normalized result shape. Command exit status remains independent evidence.
- **Security implications:** XML parsing must disable external entities and dangerous expansions. Bound report and attachment size. Sanitize output.
- **Context and token implications:** Models receive failing tests, changed outcomes, and concise summaries. Full logs and reports remain artifacts.
- **First useful implementation:** Ingest common JUnit XML produced by a project test command and bind it to command, environment, commit, and repository fingerprint.
- **Deferred features:** framework-specific enrichments, flaky-test history, coverage formats, and result publishing.
- **Exit strategy:** Support multiple parsers and retain the raw report Artifact. JUnit is not canonical.
- **Acceptance criteria:** Parser variance cannot turn an unknown result into a pass; exit status and report contradictions are disclosed; external entities are disabled.

### Durable artifact references

- **Priority:** Foundational.
- **Communication direction:** Internal references that adapters can expose.
- **Kiln's role:** Authority for stable Artifact identity and metadata, not necessarily blob storage.
- **Internal mapping:** Artifact has identity, digest, media type, size, location, producer, timestamps, repository and Run binding, retention state, and availability state.
- **Adapter boundary:** Protocol adapters exchange references or bounded content. They do not invent separate artifact truth.
- **Security implications:** Prevent path traversal, confused-deputy reads, stale links, and secret capture. Enforce workspace and retention policy at dereference time.
- **Context and token implications:** References avoid repeated large payloads. The context engine loads selected excerpts only.
- **First useful implementation:** Register a filesystem artifact with digest and producer metadata, then resolve it through permission-checked APIs.
- **Deferred features:** content-addressed storage, remote object stores, deduplication, garbage collection, and signed URLs.
- **Exit strategy:** Artifact locations can change while identity and digest remain stable.
- **Acceptance criteria:** A missing artifact is reported as unavailable, not silently recreated; digest mismatch invalidates dependent evidence.

### Evidence receipts

- **Priority:** Foundational.
- **Communication direction:** Internal production with export adapters.
- **Kiln's role:** Native evidence authority for completion.
- **Internal mapping:** receipt includes invocation, subject, inputs or materials, environment, producer, start and end time, result, termination, artifacts, repository binding, and freshness dependencies.
- **Adapter boundary:** JUnit, SARIF, command results, DAP observations, and future attestations map into or out of receipts.
- **Security implications:** Receipts must be tamper-evident enough for their use, avoid embedding secrets, and distinguish observed facts from claims. Strong signatures are deferred unless external trust requires them.
- **Context and token implications:** Models receive concise receipt summaries and can inspect details by reference. Receipts reduce repeated verification narration.
- **First useful implementation:** Create a receipt for each verification command and mark it stale after relevant repository mutation.
- **Deferred features:** signatures, transparency logs, external verification, remote builders, and policy languages.
- **Exit strategy:** The native receipt schema can evolve with versioned migrations and exporters. External formats remain projections.
- **Acceptance criteria:** A completion claim references current receipts; stale, failed, cancelled, missing, or contradictory evidence cannot become passing evidence.

### in-toto attestations

- **Priority:** Expansion.
- **Communication direction:** Outbound export and optional inbound verification.
- **Kiln's role:** Attestation producer for selected receipts and verifier for imported claims.
- **Internal mapping:** in-toto subject to Artifact or repository subject; materials to inputs; predicate invocation to Run or execution; builder to Kiln version and execution identity; result to evidence outcome.
- **Adapter boundary:** `Kiln.Evidence.Export.InToto` converts a versioned receipt into a statement and optional envelope.
- **Security implications:** Signing keys, identity, verification policy, canonicalization, replay, and subject digest integrity become critical. Do not imply trust merely because a document has in-toto shape.
- **Context and token implications:** Attestations remain Artifacts. Models receive verified summaries and predicate type.
- **First useful implementation:** Export one digest-bound receipt as an in-toto Statement v1 when a user explicitly requests it.
- **Deferred features:** DSSE signing, keyless identity, verification policies, layout enforcement, and transparency integration.
- **Exit strategy:** Regenerate attestations from native receipts. Do not store external predicates as the sole evidence record.
- **Acceptance criteria:** Subject digests match; predicate and statement versions are recorded; unsigned and unverified imports are labeled claims.

### SLSA provenance

- **Priority:** Expansion.
- **Communication direction:** Outbound for build and release artifacts.
- **Kiln's role:** Producer of provenance from reproducible build Runs, using the in-toto attestation model.
- **Internal mapping:** subject to output Artifact; build definition to declared build type and parameters; run details to execution environment and timing; builder to Kiln or delegated builder identity; materials to source and dependencies.
- **Adapter boundary:** SLSA export consumes native build receipts. It does not drive local Session state.
- **Security implications:** Provenance quality depends on builder isolation, identity, material completeness, and tamper resistance. Local generation alone does not establish a high SLSA level.
- **Context and token implications:** Provenance is for verification and publication, not routine prompt context.
- **First useful implementation:** Generate unsigned or explicitly local provenance for a reproducible release artifact with complete source revision and build command.
- **Deferred features:** hosted builders, keyless signing, higher SLSA build levels, dependency completeness, and registry publication.
- **Exit strategy:** Export newer predicate versions from retained native receipts and Artifact metadata.
- **Acceptance criteria:** Kiln states the achieved guarantees accurately and never equates schema conformance with a SLSA level.

## Rejected adoption modes

The following are classified as **Reject** even when the underlying protocol remains useful in another role:

- ACP as the internal domain or event model.
- AG-UI shared state as authoritative Session state.
- AHP as a required runtime dependency before stability and interoperability evidence.
- MCP discovery as automatic capability authority.
- MCP server support before a secure external-consumer use case.
- A2A for local child Runs or sub-agent supervision.
- raw LSP method catalogs as model tools.
- raw Tree-sitter syntax trees as routine model context.
- DAP evaluation without explicit execution permission.
- BSP adoption only to avoid defining Kiln's own execution and evidence model.
- a Skill's permission declaration as a permission grant.
- Dev Containers or OCI containers described as complete sandboxing.
- WASI or WIT as a mandatory first extension boundary.
- OpenTelemetry as the durable event journal.
- JUnit, SARIF, in-toto, or SLSA as Kiln's canonical evidence model.

## Cross-protocol adapter rules

Every protocol adapter must satisfy these rules:

1. **Native authority:** translate into native commands, queries, events, capabilities, artifacts, or evidence.
2. **Version record:** record protocol, version, implementation identity, and negotiated features.
3. **No ambient authority:** discovery and schema availability never grant execution permission.
4. **Bounded data:** enforce message, stream, catalog, output, and recursion limits.
5. **Cancellation:** map cancellation into supervised execution and record uncertain outcomes honestly.
6. **Idempotency:** protect reconnect and retry paths from duplicate side effects.
7. **Provenance:** preserve source server, client, tool, analyzer, runtime, or package identity.
8. **Freshness:** bind semantic data and evidence to repository state where relevant.
9. **Raw retention:** retain original external documents or messages only when useful, bounded, and policy-compliant.
10. **Replaceability:** adapter removal must not invalidate native Session history.
11. **Compatibility tests:** test supported versions and explicit failure for unsupported versions.
12. **Security parity:** external clients and tools cannot do more than equivalent native actions.

## First implementation sequence

This sequence is ordered by product proof, not protocol popularity.

1. Define native Event envelopes, snapshots, Artifact references, evidence receipts, capability declarations, and adapter metadata.
2. Complete the local execution kernel and prove cancellation and reconstruction.
3. Add Agent Skills-compatible discovery and lazy loading without automatic script execution.
4. Add structured test-report ingestion and evidence freshness.
5. Add normalized Tree-sitter structure for changed files.
6. Add normalized LSP semantics for one language.
7. Add one brokered local MCP client integration.
8. Add ACP after the same native event stream can serve the CLI or TUI.
9. Instrument Kiln with OpenTelemetry; add OTLP export only when useful.
10. Add worktree creation for isolated Runs when concurrency or change separation requires it.
11. Add AG-UI with LiveView or another frontend after ACP and native projections prove the stream.
12. Add DAP, SARIF, OCI or Dev Container execution, SCIP, OpenAPI, and evidence exports in response to measured workflows.
13. Keep AHP, A2A, BSP, WASI, and WIT behind watch criteria until concrete use cases exist.

## Acceptance criteria for this planning decision

This protocol plan is accepted when:

- every evaluated protocol has a priority, direction, Kiln role, adapter boundary, security position, context position, first implementation, deferred scope, exit strategy, and acceptance criteria;
- the required protocol opinions are stated without contradiction;
- every external protocol maps to native Kiln concepts;
- no protocol is required for Phase 1 local execution-kernel success;
- ACP depends on the native event model rather than defining it;
- MCP client support is ranked above MCP server support;
- MCP and OpenAPI capabilities are both mediated by the capability broker;
- LSP and Tree-sitter are exposed through bounded normalized services;
- local child Runs remain native;
- evidence formats remain import and export projections of native receipts;
- experimental protocols have explicit adoption triggers and removal paths;
- protocol support can be tested without granting broader authority than the equivalent native operation.

## Official references

- ACP: <https://agentclientprotocol.com/>
- AG-UI: <https://docs.ag-ui.com/>
- AHP: <https://microsoft.github.io/agent-host-protocol/>
- MCP: <https://modelcontextprotocol.io/specification/>
- A2A: <https://a2a-protocol.org/latest/specification/>
- OpenAPI: <https://spec.openapis.org/oas/latest.html>
- JSON Schema: <https://json-schema.org/draft/2020-12>
- LSP: <https://microsoft.github.io/language-server-protocol/>
- DAP: <https://microsoft.github.io/debug-adapter-protocol/>
- Tree-sitter: <https://tree-sitter.github.io/tree-sitter/>
- SCIP: <https://github.com/scip-code/scip>
- BSP: <https://build-server-protocol.github.io/docs/specification>
- Agent Skills: <https://agentskills.io/specification>
- Development Containers: <https://containers.dev/>
- OCI: <https://opencontainers.org/>
- WebAssembly and WASI: <https://webassembly.org/specs/>
- WIT and Component Model: <https://github.com/WebAssembly/component-model>
- OpenTelemetry: <https://opentelemetry.io/docs/specs/>
- SARIF: <https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html>
- in-toto: <https://in-toto.io/docs/specs/>
- SLSA provenance: <https://slsa.dev/spec/>
