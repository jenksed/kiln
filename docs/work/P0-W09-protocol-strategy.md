# P0-W09: Protocol and standards strategy

- **Status:** Accepted; integration in progress
- **Branch:** `work/p0-w09-protocol-strategy`
- **Depends on:** P0-W06, P0-W07, P0-W08
- **Scope:** Planning and contracts only

## Objective

Define which external protocols and standards provide direct value to Kiln without allowing protocol enthusiasm or protocol object models to define the product.

## Observed current state

- Kiln owns a protocol-neutral internal domain model.
- The Capability broker keeps implementation catalogs outside model Context.
- The Context system excludes complete MCP catalogs and raw LSP objects.
- The extension boundary is language-neutral and process-isolated.
- The accepted protocol strategy was first recorded on `main` before the complete P0-W02 through P0-W08 stack was integrated.
- The original protocol ADR used number 0004, which conflicts with the accepted Run-graph ADR sequence.

## Requirements

- **P0-W09-R01:** Rank each evaluated protocol as foundational, expansion, watch, or a rejected adoption mode.
- **P0-W09-R02:** Map each external protocol to Kiln-native concepts.
- **P0-W09-R03:** Record communication direction, Kiln's role, adapter boundary, security implications, Context implications, first useful implementation, deferred scope, exit strategy, and acceptance criteria.
- **P0-W09-R04:** Keep ACP, MCP, LSP, AG-UI, AHP, A2A, Skills, isolation, telemetry, and Evidence positions consistent with accepted domain, Capability, and Context decisions.
- **P0-W09-R05:** Preserve protocol-specific identifiers and versions at adapter boundaries.
- **P0-W09-R06:** Reconcile ADR numbering without changing the accepted decision.

## Proposed changes

- Add `docs/PROTOCOL-CAPABILITY-MAP.md` to the authoritative planning stack.
- Add ADR 0012 as the renumbered accepted protocol decision.
- Add this work-package record.
- Update the ADR index.
- Let P0-W10 reconcile the roadmap, README, planning baseline, and implementation order together with Git change isolation.

## Acceptance criteria

- **P0-W09-AC01:** Every requested protocol has a priority and internal mapping.
- **P0-W09-AC02:** Required product positions are explicit and do not contradict the internal domain model.
- **P0-W09-AC03:** Protocol catalogs cannot grant authority or enter model Context by default.
- **P0-W09-AC04:** Local Child Runs use Kiln-native execution rather than A2A.
- **P0-W09-AC05:** OpenTelemetry remains operational observation and does not replace the event journal.
- **P0-W09-AC06:** The accepted protocol ADR has a unique number after ADR 0011.

## Verification

- Inspect the capability map against `docs/INTERNAL-DOMAIN-MODEL.md`.
- Inspect MCP and Tool positions against `docs/CAPABILITY-INTEGRATION.md`.
- Inspect Context implications against `docs/CONTEXT-SYSTEM.md`.
- Parse all JSON contracts changed by later dependent work.
- Run `vale .` and `scripts/check` after the stack is integrated into a runnable checkout.

## Evidence

- **P0-W09-E01:** Protocol capability summary and detailed entries.
- **P0-W09-E02:** ADR 0012.
- **P0-W09-E03:** ADR index with unique numbering.
- **P0-W09-E04:** Repository comparison that preserves the approved protocol map while removing the duplicate ADR number.

## Exclusions

This work does not implement ACP, MCP, LSP, DAP, AG-UI, AHP, A2A, OpenTelemetry export, WASI, WIT, or any other protocol adapter.
