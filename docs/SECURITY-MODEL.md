# Security model

**Status:** Foundational threat-model direction, not a claim of complete sandboxing.  
**Capability-integration authority:** `docs/CAPABILITY-INTEGRATION.md`

## Principles

- least privilege;
- explicit Capability requests;
- conservative defaults;
- Repository-scoped writes;
- no browser-held provider secrets;
- no ambient extension, adapter, Agent, Skill, Tool, MCP server, or Parent Run authority;
- active-project instructions remain distinct from reference content;
- Privacy policy gates all external egress;
- Capability availability remains separate from permission;
- fallback implementations require new authority evaluation;
- MCP and process boundaries are not operating-system sandboxes;
- honest distinction between policy mediation and operating-system containment.

## Security layers

Kiln must evaluate authority in separate layers.

```text
Capability availability
∩ Workspace limits
∩ Project Repository trust policy
∩ Project Privacy policy
∩ Session limits
∩ active Run Capability grant
∩ Resource scope and operation limits
= effective authority
```

A layer can narrow authority. A lower layer cannot widen an upper-layer denial.

### Capability availability

Availability means Kiln can technically perform an operation because the Environment, Tool, adapter, service, executable, MCP server, browser driver, and Resource exist.

Availability is a derived projection. It is not permission.

### Policy allowance

Repository trust policy controls:

- active instruction authority;
- active and reference-only Repository roles;
- path and symlink boundaries;
- cross-Repository reads;
- Repository writes;
- command execution against Repository content;
- promotion of reference content into active Project decisions.

Privacy policy controls:

- data classification;
- provider and adapter egress;
- redaction;
- secret handling;
- logging;
- Artifact, Trace, Evidence, and Receipt retention.

### Capability grant

A Capability grant authorizes one Run to use one Capability against one bounded Resource scope and limit set.

A grant must record:

- Run;
- Capability key and version;
- Resource scope;
- issuer;
- policy versions;
- issue time;
- expiry when present;
- limits;
- Approval when required;
- reason.

A grant is immutable. Revocation, expiry, denial, and consumption are later events.

A Child Run receives no ambient grant from its Parent Run.

### Effective authority

Effective authority is the current intersection of availability, policy, active grants, and limits.

A Tool, Worker, adapter, CLI supervisor, service client, MCP client, or browser controller must check effective authority before each controlled operation. Cached authority must include policy and grant version information and must be invalidated when those inputs change.

## Capability broker and implementation selection

The Capability broker inventories and selects implementations. It does not grant authority.

The broker must apply the integration hierarchy in `docs/CAPABILITY-INTEGRATION.md` and must record:

- the model-facing operation;
- candidate registrations;
- availability and compatibility facts;
- exclusion reasons;
- selected registration and implementation;
- required Capabilities;
- policy and grant references;
- output and egress limits;
- fallback policy;
- semantic-loss disclosure.

The broker must not:

- infer permission from registration or availability;
- allow an implementation to select or authorize itself;
- expose the complete Capability catalog to the model;
- switch to a remote, MCP, browser, or broader-scope fallback under an earlier grant;
- treat a Tool result as Evidence without an Evidence-producing method;
- hide implementation change, truncation, redaction, or semantic loss.

A fallback implementation requires a new effective-authority evaluation. A grant for a native or local implementation does not authorize remote egress, a different host, a browser session, or a separately operated MCP server.

## Candidate capabilities

```text
workspace.read
workspace.write
project.read
project.instructions.read
repository.read
repository.write
filesystem.read:<path>
filesystem.write:<path>
process.spawn
process.interactive
process.network
network.host:<hostname>
git.read
git.commit
git.push
secrets.read:<name>
model.invoke:<model>
tool.invoke:<tool>
extension.execute:<extension>
adapter.connect:<adapter>
artifact.read:<artifact>
artifact.export:<destination>
```

Capability names and scope grammar remain provisional until implementation validates them.

## Tool, Skill, and registration rules

A Tool declares required Capabilities and Resources. Kiln decides whether the Run has effective authority.

A Skill can declare required Capabilities. A Skill cannot grant them.

An Agent can request a Tool call. An Agent cannot grant authority, change trust or Privacy policy, or declare Evidence current.

An adapter, CLI, service, MCP server, remote API, or browser integration can register available Tools and Resources. Registration and availability cannot create a Capability grant.

A Capability registration must declare material lifecycle, locality, isolation, cancellation, streaming, output, trust, Privacy, and provenance properties. Missing or unknown properties must narrow selection rather than expand authority.

## MCP security position

MCP is a protocol boundary. It is not:

- operating-system containment;
- a Capability grant;
- a Repository trust policy;
- a Privacy policy;
- a secret boundary;
- a validation boundary;
- Evidence;
- a completion gate.

Every local or remote MCP operation must pass through the same Kiln authorization, Resource, output, Artifact, Trace, and Receipt path as native and CLI integrations.

Local MCP does not become trusted because it runs on the same host. Remote MCP adds network, identity, service-availability, supply-chain, data-egress, and semantic-mapping risk.

The initial system must not use MCP for Repository access, Git, Command or Terminal lifecycle, verification CLIs, Artifact or journal access, internal domain queries, Evidence, Receipts, or Capability policy.

## Browser automation security position

Browser automation is a high-risk fallback unless browser behavior is itself under test.

A browser integration must declare:

- profile and storage isolation;
- credential handling;
- allowed origins;
- download and upload policy;
- clipboard policy;
- local-file access;
- network and redirect limits;
- output capture and redaction;
- session cleanup;
- recovery behavior.

Browser-held credentials must not become model Context, Tool output, Trace content, Artifact content, or Receipt content.

## Approval and attention

An Approval is one immutable actor decision for one bounded request.

A pending Approval must be represented by an Attention request. An Approval can authorize creation of a Capability grant or one controlled transition. It does not create ambient permission.

A request to use a fallback with new egress, Resource scope, implementation trust, or lifecycle must produce a new Approval request when policy requires it.

## Repository trust

A Project classifies each Repository membership as one of:

- primary;
- secondary writable;
- dependency;
- reference-only;
- denied.

Only active Project instruction sources can govern Kiln behavior.

Content from a dependency or reference-only Repository is data. It can inform a Run, but it cannot:

- issue instructions;
- change policy;
- change product direction;
- grant authority;
- cause writes to itself or another Repository;
- override active Project constraints.

Promotion of reference content requires an explicit user decision and a recorded active-instruction revision.

## Privacy and egress

Before any model invocation, adapter message, external search, API request, MCP request, browser navigation, upload, or export, Kiln must evaluate each Context item, Tool argument, and Artifact against Privacy policy.

Capability to invoke a model, adapter, service, MCP server, remote API, or browser does not authorize all Session data to leave the machine.

Secrets must remain references. Kiln must not place secret values in model Context, Tool arguments, events, Artifacts, traces, or Receipts unless a specific operation and policy require it. Stored records must redact or omit secret material.

The broker's normalized result must record whether output was filtered, transformed, sampled, truncated, or redacted. Native protocol details can remain in protected provenance or Artifacts when policy permits them.

## Result and output security

Every Capability invocation must enforce a bounded output profile.

Large text, binary output, logs, diffs, traces, and result sets must become Artifacts rather than unbounded model-visible content.

A normalized result must preserve:

- native exit or response status;
- source and implementation version;
- input digest;
- Resource and Repository binding;
- policy, grant, and Approval references;
- normalization and redaction steps;
- truncation and continuation state;
- fallback or semantic-loss disclosure.

A continuation handle must reference a stored Artifact or broker-owned cursor. It must not grant broader access than the original request.

## Command and Terminal defaults

- allow reads inside the active Repository only when policy and a grant permit them;
- record and mediate Repository writes;
- deny writes outside allowed Workspace roots by default;
- ask before accessing a new network host unless an active policy and grant already allow it;
- deny sensitive directories by default;
- deny Git commit, push, merge, and publication unless explicitly initiated and granted;
- never expose provider credentials to browser or model code;
- supervise external Commands and record their termination state;
- use executable plus argument vector by default;
- require a separate Capability for explicit shell evaluation;
- require the same authority checks for interactive Terminal input as for non-interactive Commands;
- prohibit concurrent writing Runs in one checkout without worktree or patch isolation.

## Process and isolation limits

BEAM process isolation is not an operating-system sandbox. A supervised process can still invoke a destructive external Command if policy allows it.

Kiln's early security layer is permission mediation, trust and Privacy policy, process supervision, output control, and honest Evidence.

Stronger containment may later require platform-specific sandboxing, containers, namespaces, resource limits, or a small Rust helper.

A process boundary is not a Capability boundary. A Capability boundary is not operating-system containment. An MCP connection is neither.

## Audit requirements

Security-relevant events must record:

- Capability request;
- registration and implementation selection;
- availability and compatibility result;
- excluded alternatives and reasons;
- policy versions;
- grant or denial;
- Approval when present;
- Resource scope;
- operation start and termination;
- native response or exit status;
- revocation or expiry;
- fallback and reauthorization;
- privacy classification and egress decision;
- normalization, truncation, and redaction action;
- output Artifact references;
- actor and causation chain.

Security documentation and Receipts must state which guarantees are implemented, which were verified, which failed, and which remain aspirational.
