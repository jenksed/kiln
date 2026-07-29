# ADR-0023: Use the MiniMax M2.7 OpenAI-compatible API

**Document type:** Explanation  
**Status:** Accepted  
**Integration status:** Proposed on `work/p0-w22-model-context-repository-boundary`  
**Date:** 2026-07-28  
**Work package:** P0-W22  
**Depends on:** ADR-0021

## Context

OD-01 selects MiniMax as the only initial real provider, requires one deterministic fake, permits only a sealed Context package under accepted Project disclosure policy, and forbids fallback.

P0-W22 must select one concrete current API and model mapping without creating a provider router, SDK framework, Agent catalog, or broad OpenAI compatibility layer.

MiniMax currently documents:

- an OpenAI-compatible text endpoint at `/v1/chat/completions`;
- model `MiniMax-M2.7`;
- streaming text responses;
- function-style Tool calls;
- usage fields;
- optional separated reasoning fields;
- Bearer-token authentication.

## Decision drivers

- Preserve OD-01 exactly.
- Use one current documented coding-capable text model.
- Support bounded Tool use and streaming.
- Keep provider-specific mapping behind one Kiln-native behaviour.
- Avoid a general provider SDK or routing dependency.
- Prevent provider-native reasoning from becoming durable state or Evidence.
- Make cancellation and uncertain results conservative.
- Keep the decision reversible behind one adapter while preserving historical manifests.

## Considered options

### Option A: Direct OpenAI-compatible HTTP mapping

Use direct bounded HTTP and JSON mapping to:

```text
https://api.minimax.io/v1/chat/completions
```

with model `MiniMax-M2.7`.

Advantages:

- current official endpoint and model;
- supports streaming and Tools;
- smallest dependency boundary;
- keeps request, timeout, cancellation, malformed-result, and retention behavior explicit;
- does not import a broad OpenAI client contract into Kiln.

Disadvantages:

- Kiln owns streaming and JSON normalization;
- compatibility differences must be tested explicitly;
- provider changes require adapter maintenance.

### Option B: Anthropic-compatible MiniMax endpoint through an SDK

MiniMax recommends Anthropic SDK integration in some current guidance.

Advantages:

- supported current integration path;
- existing SDK event handling.

Disadvantages:

- introduces an external provider SDK boundary before Kiln has a second consumer;
- can expose provider-specific message and reasoning objects more broadly;
- does not reduce Kiln's responsibility for disclosure, operation state, Tool authority, or Evidence.

### Option C: General OpenAI client abstraction

Use a general client library and treat MiniMax as one OpenAI-compatible provider.

Advantages:

- potentially reusable for later providers.

Disadvantages:

- creates routing and compatibility pressure before a second provider exists;
- can hide unsupported parameter and event differences;
- conflicts with the no-router and smallest-boundary decisions.

### Option D: MiniMax high-speed model

Use `MiniMax-M2.7-highspeed` initially.

Advantages:

- faster documented output.

Disadvantages:

- speed is not the first acceptance criterion;
- can add cost or quota assumptions without measured need;
- a later model-profile change is reversible.

## Decision

Select Option A.

The first real provider profile is:

```text
provider_id: minimax
api_family: minimax-openai-compatible/v1
endpoint: https://api.minimax.io/v1/chat/completions
model: MiniMax-M2.7
stream: true
fallback: none
```

Additional rules:

1. Use direct bounded HTTP and JSON mapping behind a Kiln-native provider behaviour.
2. Do not add a general OpenAI client abstraction, provider router, fallback, or ensemble.
3. Use one deterministic fake implementation of the same Kiln behaviour for tests.
4. Request separated reasoning where the API supports it.
5. Keep provider-native reasoning transient inside the live Worker and do not persist or expose it as Evidence.
6. Persist normalized visible content, Tool calls, usage, metadata, warnings, and digests only as defined by P0-W22.
7. Use no automatic retry after dispatch.
8. Treat local cancellation or connection loss after dispatch as an unknown hosted effect unless a terminal provider result was observed.
9. Resolve credentials through an opaque `MINIMAX_API_KEY` reference and never persist the value.
10. A later model change requires an accepted provider-profile revision and must not rewrite historical Context manifests or results.

## Consequences

### Positive

- P1-S02 has one concrete provider target.
- Tool and stream behavior can be tested against one normalized contract.
- Provider-specific details stay outside core domain state.
- The deterministic fake can prove workflow behavior without network access.
- No unused provider-routing infrastructure enters the first product.

### Negative

- Kiln must implement and test stream parsing and compatibility details.
- MiniMax API changes can require adapter updates.
- A dispatched request cannot be assumed canceled merely because the local connection closed.
- Hosted-provider retention remains outside Kiln control.

### Neutral or operational

- The HTTP dependency and exact version are selected only by an authorized implementation ticket.
- The Project must explicitly accept hosted MiniMax disclosure before source excerpts leave the machine.
- Provider model, endpoint, limits, and mapping are included in Context and result provenance.

## Evidence and assumptions

### Observed evidence

| Claim | Evidence | Date |
| --- | --- | --- |
| MiniMax is the only initial provider | ADR-0021 | 2026-07-28 |
| MiniMax documents the OpenAI-compatible endpoint | Official MiniMax API documentation | 2026-07-28 |
| MiniMax documents `MiniMax-M2.7`, streaming, Tools, and usage | Official MiniMax API documentation | 2026-07-28 |
| Kiln currently has no provider dependency or implementation | `mix.exs`; implementation inventory | current baseline |

### Inferences

- Direct HTTP is the smallest sufficient boundary for one provider.
- The non-high-speed model is the conservative starting profile because correctness and bounded behavior matter before throughput.
- Provider-native reasoning must remain transient because it is not accepted durable work state or Evidence.

### Unknowns

- Provider-side storage, abuse review, and deletion behavior are not established by the reviewed API references.
- Exact live timeout and throughput behavior must be measured in an authorized smoke path.
- The current model or endpoint can change before implementation. The dependency review must revalidate official documentation without silently selecting a different model.

## Verification

The authorized provider ticket must prove:

- exact endpoint and model mapping;
- credential non-disclosure;
- streaming visible text and Tool-call normalization;
- deterministic fake parity for accepted result classes;
- no fallback;
- Context and Tool digests in the request;
- timeout, malformed response, rate limit, connection loss, and cancellation behavior;
- provider reasoning is not persisted;
- no provider SDK, router, Agent catalog, or broad OpenAI abstraction enters without a new accepted decision.
