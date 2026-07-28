# Architecture decision records

**Document type:** Reference

Architecture decision records (ADRs) preserve decisions that constrain future implementation.

Use `docs/templates/ADR.md` for new records. Follow `docs/ENGINEERING-QUALITY-RULES.md`.

## Status vocabulary

- **Proposed:** under review and not yet binding.
- **Accepted:** current project constraint.
- **Superseded:** replaced by a later ADR.
- **Rejected:** considered and deliberately not chosen.

An accepted ADR MUST NOT be reversed without a superseding ADR.

## Records

- [ADR 0001: Elixir and OTP own the initial runtime](0001-elixir-otp-core.md)
- [ADR 0002: Persist a session journal separate from the transcript](0002-durable-session-journal.md)
- [ADR 0003: Use a language-neutral external extension boundary](0003-language-neutral-extensions.md)
- [ADR 0004: Model delegated work as first-class runs](0004-first-class-run-graph.md)
- [ADR 0005: Attach Project Steward responsibility to the root run](0005-project-steward.md)
