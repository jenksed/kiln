# P2-X01: Provider Access Spike

**Document type:** Reference  
**Status:** In progress  
**Branch:** `spike/p2-x01-provider-access`  
**Depends on:** P0-W03 agent-ready development controls

## Question

Can Kiln call MiniMax through a small direct adapter now and preserve a future boundary for Kimi and Codex platform-managed authentication without coupling provider work to the Phase 1 session engine?

## Effort limit

Limit the first experiment to:

- one direct OpenAI-compatible transport;
- one MiniMax configuration wrapper;
- model listing;
- one non-streaming chat request;
- one opt-in smoke Mix task;
- local stub tests;
- documented Kimi ACP and Codex app-server probes.

Do not implement a complete model loop, tool execution, persistent provider events, or managed-client protocols in this experiment.

## Observed current state and evidence

| Observation | Evidence | Collected by | Date |
| --- | --- | --- | --- |
| Kiln is a runnable Elixir application seed with no provider code. | `mix.exs` and `lib/kiln/` on the spike base | ChatGPT GitHub connector | 2026-07-28 |
| MiniMax exposes an OpenAI-compatible API at `https://api.minimax.io/v1` and accepts Token Plan keys. | MiniMax official API documentation | ChatGPT web research | 2026-07-28 |
| Kimi Code supports account OAuth through `kimi login` and ACP through `kimi acp`. | Kimi Code official documentation | ChatGPT web research | 2026-07-28 |
| Codex app-server supports API-key and ChatGPT-managed authentication through its account JSON-RPC interface. | OpenAI Codex app-server documentation | ChatGPT web research | 2026-07-28 |
| Erlang/OTP 28 includes `:json` and `:httpc`. | Erlang/OTP official documentation | ChatGPT web research | 2026-07-28 |

## Assumptions and unknowns

### Assumptions

- **P2-X01-A01:** The user's MiniMax Token Plan key is available locally as `MINIMAX_API_KEY`.
- **P2-X01-A02:** A built-in OTP transport is sufficient for an initial non-streaming experiment.
- **P2-X01-A03:** Kimi and Codex managed sign-in should remain owned by their official client processes.

### Unknowns

- **P2-X01-U01:** Unknown. The exact MiniMax streaming and tool-call event variants must be observed through a later live experiment.
- **P2-X01-U02:** Unknown. The Kimi ACP capabilities that Kiln needs must be confirmed through protocol initialization.
- **P2-X01-U03:** Unknown. The Codex app-server protocol version and capabilities installed on the user's machine must be queried at runtime.
- **P2-X01-U04:** Unknown. Direct Kimi Code membership API use by a new custom client may require product-specific authorization. Use Kimi ACP or Kimi Open Platform until the applicable terms are confirmed.

## Requirements

- **P2-X01-R01:** The experiment shall not require a third-party Elixir runtime dependency.
- **P2-X01-R02:** The direct adapter shall read the MiniMax credential from local process environment only.
- **P2-X01-R03:** The direct adapter shall not include credentials in returned errors.
- **P2-X01-R04:** The adapter shall send an identifying Kiln user-agent value.
- **P2-X01-R05:** The adapter shall normalize transport, authorization, rate-limit, request, upstream, and invalid-response failures.
- **P2-X01-R06:** Continuous integration shall use a local stub server and shall not use live provider credentials.
- **P2-X01-R07:** A live MiniMax request shall require an explicit Mix task invocation.
- **P2-X01-R08:** Kimi OAuth credentials shall remain owned by the official Kimi client.
- **P2-X01-R09:** Codex ChatGPT credentials shall remain owned by Codex app-server.
- **P2-X01-R10:** Experimental provider code shall not enter the Phase 1 session loop.

## Proposed changes

1. Add a validated OpenAI-compatible provider configuration struct.
2. Add a small HTTP and JSON transport using OTP applications.
3. Add a MiniMax wrapper with environment-based configuration.
4. Add `mix kiln.minimax.smoke` for explicit live testing.
5. Add local transport tests with a TCP HTTP stub.
6. Add managed-client probe scripts for Kimi and Codex only after direct MiniMax tests pass.
7. Record observed response and error shapes before proposing a neutral provider contract.

## Files or components expected to change

| Path or component | Expected change |
| --- | --- |
| `docs/PROVIDER-ACCESS-DIRECTION.md` | Record direct and managed-client access boundaries. |
| `lib/kiln/providers/openai_compatible/` | Add experimental direct provider transport. |
| `lib/kiln/providers/minimax.ex` | Add MiniMax configuration and response helpers. |
| `lib/mix/tasks/kiln.minimax.smoke.ex` | Add opt-in live smoke task. |
| `test/kiln/providers/` | Add local transport tests. |
| `test/support/http_stub.ex` | Add local HTTP stub. |
| `mix.exs` | Start the OTP HTTP and TLS applications. |

## Acceptance criteria

- **P2-X01-AC01**
  - **Given** a local stub that returns an OpenAI-compatible model list
  - **When** the adapter requests `/models`
  - **Then** the adapter returns the decoded model data and sends bearer authentication
  - **Evidence:** ExUnit result and captured request

- **P2-X01-AC02**
  - **Given** a local stub that returns one chat completion
  - **When** the adapter sends a user message
  - **Then** the adapter returns the decoded completion and the MiniMax wrapper extracts assistant text
  - **Evidence:** ExUnit result

- **P2-X01-AC03**
  - **Given** a local stub that returns status `401`
  - **When** the adapter handles the response
  - **Then** the adapter returns an authorization error that does not contain the configured API key
  - **Evidence:** ExUnit result

- **P2-X01-AC04**
  - **Given** `MINIMAX_API_KEY` is absent
  - **When** the smoke task builds MiniMax configuration
  - **Then** the task stops before a network request and states the missing variable
  - **Evidence:** configuration test or command result

- **P2-X01-AC05**
  - **Given** the experiment branch
  - **When** CI runs
  - **Then** it passes without provider credentials or external network requests
  - **Evidence:** CI run

## Verification commands

```bash
mix test test/kiln/providers
scripts/check
```

Optional live verification:

```bash
MINIMAX_API_KEY='<local-token-plan-key>' mix kiln.minimax.smoke
```

The live command MUST NOT run in CI.

## Required evidence

| Evidence ID | Criterion | Required evidence |
| --- | --- | --- |
| P2-X01-E01 | P2-X01-AC01 | Passing local model-list transport test and captured authorization header. |
| P2-X01-E02 | P2-X01-AC02 | Passing local chat transport test. |
| P2-X01-E03 | P2-X01-AC03 | Passing unauthorized-response redaction test. |
| P2-X01-E04 | P2-X01-AC04 | Missing-key result with no network call. |
| P2-X01-E05 | P2-X01-AC05 | Passing CI without provider secrets. |

## Decision informed

The experiment will decide:

- whether the built-in OTP transport is suitable for the first direct adapter;
- which response and error shapes belong in the future neutral provider contract;
- whether MiniMax can become the first Phase 2 provider without adding a runtime dependency;
- whether Kimi and Codex should use managed agent bridges instead of direct model adapters for subscription sign-in.

## Explicit exclusions

- streaming response implementation;
- tool-call execution;
- context compaction;
- provider event persistence;
- Phase 1 session integration;
- Kimi ACP implementation;
- Codex app-server implementation;
- credential storage;
- automatic login;
- CI live-provider tests;
- a merge recommendation for experimental code before evidence review.

## Completion record

**Result:** In progress

No verification has run for the current experiment code.
