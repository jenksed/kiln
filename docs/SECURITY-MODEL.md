# Security model

**Status:** Foundational threat-model direction, not a claim of complete sandboxing.

## Principles

- least privilege;
- explicit Capability requests;
- conservative defaults;
- Repository-scoped writes;
- no browser-held provider secrets;
- no ambient extension, adapter, Agent, Skill, Tool, or Parent Run authority;
- active-project instructions remain distinct from reference content;
- Privacy policy gates all external egress;
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

Availability means Kiln can technically perform an operation because the Environment, Tool, adapter, and Resource exist.

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

A Tool or Worker must check effective authority before each controlled operation. Cached authority must include policy and grant version information and must be invalidated when those inputs change.

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

Capability names and scope grammar remain provisional until the capability-policy ADR and implementation slice validate them.

## Tool and Skill rules

A Tool declares required Capabilities and Resources. Kiln decides whether the Run has effective authority.

A Skill can declare required Capabilities. A Skill cannot grant them.

An Agent can request a Tool call. An Agent cannot grant authority, change trust or Privacy policy, or declare Evidence current.

An adapter can expose available Tools and Resources. Adapter availability cannot create a Capability grant.

## Approval and attention

An Approval is one immutable actor decision for one bounded request.

A pending Approval must be represented by an Attention request. An Approval can authorize creation of a Capability grant or one controlled transition. It does not create ambient permission.

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

Before any model invocation, adapter message, external search, upload, or export, Kiln must evaluate each Context item and Artifact against Privacy policy.

Capability to invoke a model or adapter does not authorize all Session data to leave the machine.

Secrets must remain references. Kiln must not place secret values in model Context, Tool arguments, events, Artifacts, traces, or Receipts unless a specific operation and policy require it. Stored records must redact or omit secret material.

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
- require a separate capability for explicit shell evaluation;
- require the same authority checks for interactive Terminal input as for non-interactive Commands;
- prohibit concurrent writing Runs in one checkout without worktree or patch isolation.

## Process and isolation limits

BEAM process isolation is not an operating-system sandbox. A supervised process can still invoke a destructive external Command if policy allows it.

Kiln's early security layer is permission mediation, trust and Privacy policy, process supervision, and honest evidence.

Stronger containment may later require platform-specific sandboxing, containers, namespaces, resource limits, or a small Rust helper.

A process boundary is not a Capability boundary. A Capability boundary is not operating-system containment.

## Audit requirements

Security-relevant events must record:

- Capability request;
- availability result;
- policy versions;
- grant or denial;
- Approval when present;
- Resource scope;
- operation start and termination;
- revocation or expiry;
- privacy classification and egress decision;
- redaction action;
- actor and causation chain.

Security documentation and Receipts must state which guarantees are implemented, which were verified, which failed, and which remain aspirational.
