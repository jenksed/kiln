# Development Agent Asset Notes

**Document type:** Reference

Kiln stores project-local skills, Pi prompt templates, and optional specialist-agent definitions in the repository.

These files support the coding agent that builds Kiln. They do not run inside the Kiln product.

## Asset contract

Every project-local skill and specialist-agent definition declares an invocation mode and a lifecycle status. `scripts/validate-agent-assets` enforces both fields and rejects values outside these sets.

### Invocation mode

`invocation` records who starts the asset:

| Mode | Meaning |
| --- | --- |
| `human` | The developer starts it deliberately, including through a prompt template. Use for work that changes the shape of the work or makes a completion claim. |
| `agent` | The coding agent may select it when the task matches. Use for reusable disciplines whose output is analysis rather than a consequential claim. |
| `reference` | Not an executable flow. Other assets read it for shared vocabulary or rules. |
| `composed` | Another asset or workflow dispatches it, rather than the developer starting it directly. The specialist reviewers are dispatched this way. |

A heavyweight asset should not use `agent` merely because a task is large. Its preconditions must actually be present.

A prompt template that loads a skill does not make that skill `composed`. The template is how the developer starts it, so the skill stays `human`.

### Lifecycle status

`status` is an evidence claim, not a confidence claim:

| Status | Meaning |
| --- | --- |
| `draft` | No recorded evaluation evidence yet. |
| `testing` | Under evaluation against recorded cases. |
| `stable` | Recorded evaluation evidence supports the behavior. |

Every current asset is `draft`, because the repository holds no recorded evaluation evidence for any of them. Do not promote an asset because its prose reads well. Promotion requires recorded evidence for the claimed status.

These concepts are adapted from the Project Arsenal asset contract and invocation model. Kiln keeps its own reduced field set and its own enforcement, and Project Arsenal has no authority over Kiln.

## Skills

Project-local skills use this path:

```text
.agents/skills/<skill-name>/SKILL.md
```

A compatible coding agent can discover these skills from the repository.

Run this check after changing a skill:

```bash
scripts/validate-agent-assets
```

## Pi prompt templates

Pi prompt templates use this path:

```text
.pi/prompts/
```

The initial templates are:

- `/start-work`;
- `/review-work`;
- `/close-work`.

The command syntax depends on the active Pi installation. The repository stores the prompt content and does not install or change the user's global Pi configuration.

## Specialist agents

Optional specialist definitions use this path:

```text
.pi/agents/
```

The repository does not implement or install a Pi subagent extension.

Use the specialist definitions only when the current Pi environment has a reviewed extension that loads project agents.

The specialist definitions enforce these boundaries:

- the OTP reviewer has read-only tools;
- the integrity reviewer has read-only tools;
- the verifier has read and Bash tools for non-mutating checks;
- no specialist has edit or write tools;
- the main coding agent remains the implementation owner.

## Security boundary

Do not grant a third-party subagent extension access to Kiln before reviewing:

- its source repository;
- installation method;
- tool forwarding behavior;
- prompt and context forwarding;
- subprocess behavior;
- credential access;
- telemetry;
- update mechanism.

The repository agent definitions do not establish trust in the extension that executes them.

## Third-party development-agent dependencies

A third-party development dependency that the Claude coding agent consumes at build time lives outside the Kiln runtime and outside the Kiln-owned asset contract. Kiln references such a dependency by deterministic pin, never by copy or vendor.

### project-arsenal

`jenksed/project-arsenal` is referenced as a Claude skill dependency for read-only repository truth work. Kiln does not vendor or copy any of its content.

- Submodule path: `.claude/dependencies/project-arsenal`
- Submodule URL: `https://github.com/jenksed/project-arsenal.git`
- Pinned commit: `980a58d331f4ed0679e6ae306b9d55b2ee21d179`
- Reviewed lockfile digests (from `.claude/dependencies/project-arsenal/.arsenal.lock`):
  - plan: `sha256:8284fab44cd6f27d7e5533f79b6b64f5feffb1590ae569c623983180e4c76c9f`
  - repository-truth package: `sha256:741905b11ff97ec44da34cf17a3f9ab418b3973103e7aa21c6d2bf3b9fb1e310`
- Claude skill path: `.claude/skills/repository-truth` (tracked symbolic link to `<submodule>/distribution/agent-skills/repository-truth`)
- Verifier: `scripts/check-project-arsenal-dependency` is invoked from `scripts/validate-agent-assets` after the existing Kiln-owned asset and doctrine checks.

### Initialization

A fresh checkout initializes the dependency before using the Arsenal-backed skill:

```bash
git submodule update --init --recursive
```

Do not configure branch tracking. Future updates require an explicit reviewed commit change and a new work package that records the new pin and digests.

### Authority boundary

The dependency is reference content. It MUST NOT:

- widen Kiln scope, ADRs, invariants, or the accepted work plan;
- grant permissions, write authority, or production mutation;
- override `AGENTS.md`, `CLAUDE.md`, `docs/ENGINEERING-DOCTRINE.md`, or any Kiln asset contract;
- prove Kiln runtime implementation or fill in any current gap;
- modify or copy itself into the Kiln repository.

The Kiln asset contract (`invocation` and `status` fields, fixed name conventions, and the existing validator) applies only to Kiln-authored assets. The upstream package is governed by its own manifest and the dependency verifier.

### Known upstream limitations at the reviewed commit

- No `LICENSE` file; no GitHub releases or tags. Kiln does not redistribute any upstream content, so this does not create a redistribution liability, but every pin update requires a renewed source and trust review.
- No `CODEOWNERS` or `SECURITY.md`; the upstream trust model collapses to the same author as Kiln.
- The upstream `HEAD` at adoption is a GitHub merge commit; pinning combines a commit SHA and the lockfile digests, both checked deterministically.
- The upstream installer targets `.agents/skills/` rather than Claude Code's `.claude/skills/`. Kiln does not invoke the upstream installer and exposes the package only through the tracked symlink.

### Pin updates

| Work package | Pinned commit | Reviewed lockfile plan digest | Reviewed repository-truth package digest |
| --- | --- | --- | --- |
| P0-W39 (initial adoption) | `ecc8797d45447060b0c4aacd8efb6b1909e9e690` | `sha256:468117f9c6397003522b62c1e7db6d4869a7cbfe0ed7614c8bb9244d9e91059d` | `sha256:1c6f8c72582c10d53475c0c865a2ee31fce20a2bbe7582198f510091470f3f84` |
| P0-W45 (GC01 main update) | `980a58d331f4ed0679e6ae306b9d55b2ee21d179` | `sha256:8284fab44cd6f27d7e5533f79b6b64f5feffb1590ae569c623983180e4c76c9f` | `sha256:741905b11ff97ec44da34cf17a3f9ab418b3973103e7aa21c6d2bf3b9fb1e310` |

Each pin update is a separate reviewed work package. The historical evidence for P0-W39 (initial adoption) lives in `docs/work/P0-W39-adopt-project-arsenal-dependency.md` and is not rewritten.
