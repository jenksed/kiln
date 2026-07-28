---
name: kiln-dependency-review
description: Evaluates a proposed Elixir, Erlang, Rust, JavaScript, or system dependency before it enters Kiln. Use for libraries, executables, services, NIFs, ports, and development tools.
compatibility: Requires access to current official documentation and repository files.
---

# Kiln Dependency Review

Use this skill before modifying `mix.exs`, runtime installation files, CI setup, or external-tool configuration.

## Required input

Identify:

- work-package ID;
- requirement that needs the dependency;
- proposed dependency and exact version;
- runtime, development, or optional scope.

## Evidence collection

Inspect current sources in this order:

1. official project documentation;
2. official source repository;
3. package registry metadata;
4. release notes and changelog;
5. security advisories;
6. license files;
7. source code for the interfaces Kiln will call.

Do not rely on model memory for current versions, maintenance state, or API shape.

## Evaluation

Record:

```text
Requirement served:
Exact version:
Scope:
Official interface inspected:
Release date:
Maintenance evidence:
License:
Transitive dependencies:
Native code or NIF use:
Network or process access:
Data and secret exposure:
Failure modes:
Upgrade and removal cost:
Standard-library alternative:
Other alternatives:
Reason to accept or reject:
Unknowns:
Cheapest verification:
```

## Decision rules

Reject or defer the dependency when:

- no accepted requirement needs it;
- the standard library satisfies the requirement with clear code;
- the project would use only a small, stable portion that is cheaper to implement directly;
- maintenance or license status is unknown and material;
- a NIF can crash the BEAM and the benefit does not justify the risk;
- the dependency gains machine, network, or secret access beyond the requirement;
- the dependency forces a product architecture decision that has no ADR;
- the dependency is added only because it is common in other applications.

A development dependency still affects maintenance and supply-chain exposure. Review it with the same evidence discipline.

## Output

Return one of:

- `Accept` with conditions and verification;
- `Defer` with the missing evidence or later trigger;
- `Reject` with the lower-cost alternative;
- `Spike` with one bounded question and evidence target.

Do not edit dependency files until the work-package owner accepts the result.
