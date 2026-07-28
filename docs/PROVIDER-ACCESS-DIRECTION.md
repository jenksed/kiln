# Provider Access Direction

**Document type:** Explanation

This document records the provider-access direction established before provider implementation begins.

Provider adapters are Kiln product components. Project-local development agents and skills are not provider adapters.

## MiniMax

Kiln SHOULD test MiniMax first through the OpenAI-compatible API.

Initial configuration:

```text
Base URL: https://api.minimax.io/v1
Authentication: Bearer API key
Initial model: MiniMax-M2.7
Optional model: MiniMax-M2.7-highspeed
```

The project owner has an active MiniMax Token Plan. Kiln MUST use a Token Plan key only through local secret configuration. Kiln MUST NOT store the key in the repository, event journal, model transcript, browser code, or completion evidence.

The first MiniMax experiment SHOULD test:

- model discovery;
- one non-streaming response;
- one streaming response;
- request cancellation;
- provider error normalization;
- tool-call event shape;
- reasoning-content preservation without exposing private reasoning in user-facing output.

## Kimi

Kimi requires two distinct access paths.

### Direct API path

A direct Kimi adapter MAY use an OpenAI-compatible API key when the selected Kimi product and its terms permit use by Kiln.

Kimi Code membership keys and Kimi Open Platform keys are separate credentials with different endpoints and billing.

Kiln MUST NOT assume that one Kimi key works with another Kimi endpoint.

### Managed-client path

Kiln SHOULD evaluate the official Kimi Code CLI as a managed client bridge.

The user completes platform sign-in through:

```bash
kimi login
```

Kiln can later start:

```bash
kimi acp
```

The official CLI owns OAuth credentials. Kiln communicates through Agent Client Protocol (ACP) over standard input and output.

Kiln MUST NOT read, copy, export, or persist Kimi OAuth tokens.

This path provides platform sign-in but represents an agent-client bridge rather than a raw language-model adapter. The architecture MUST keep that distinction explicit.

## Codex

Kiln SHOULD evaluate Codex through `codex app-server`.

Codex app-server owns ChatGPT authentication and exposes account login through its JSON-RPC interface. Supported managed flows include browser OAuth and device-code authentication.

Kiln MUST let Codex own token persistence and refresh.

Kiln MUST NOT parse, copy, or persist Codex ChatGPT refresh tokens.

A Codex bridge SHOULD:

- start or attach to an isolated app-server process;
- read current account state through the documented account interface;
- initiate login only after an explicit user action;
- show the authorization URL or device code;
- wait for documented completion notifications;
- keep Codex sessions separate from Kiln's direct provider sessions;
- preserve Codex process and protocol version evidence.

Codex app-server is an agent runtime bridge. It is not equivalent to a direct OpenAI model adapter.

## Provider boundary

Kiln SHOULD use two provider boundary types:

```text
Direct model provider
  OpenAI-compatible or provider-native model API

Managed agent bridge
  Official external agent process with its own authentication and session semantics
```

Both boundary types MAY emit a common subset of neutral events. Kiln MUST NOT erase differences in:

- authentication ownership;
- session ownership;
- tool ownership;
- approval behavior;
- cancellation;
- usage reporting;
- model selection;
- persistence;
- completion semantics.

## Implementation order

1. Complete P0-W03 agent-ready development controls.
2. Run `spike/p2-x01-provider-access`.
3. Implement a minimal MiniMax direct adapter and smoke command on the spike branch.
4. Record actual response, stream, cancellation, and error evidence.
5. Define the neutral provider contract from observed data.
6. Evaluate Kimi ACP and Codex app-server as separate managed bridges.
7. Keep all experiment code outside the Phase 1 session loop.
8. Convert accepted experiment code into a Phase 2 work package after Phase 1 exits.

## Security rules

- Credentials MUST enter through environment variables or a future approved secret store.
- Error output MUST redact authorization headers and token-shaped values.
- Tests MUST use fixtures or local stub servers by default.
- Live provider tests MUST be opt-in and MUST identify expected cost or quota use.
- Continuous integration MUST NOT require live provider credentials.
- A provider adapter MUST NOT write credentials to application configuration without explicit user approval.
