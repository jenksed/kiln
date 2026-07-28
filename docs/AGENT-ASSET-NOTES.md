# Development Agent Asset Notes

**Document type:** Reference

Kiln stores project-local skills, Pi prompt templates, and optional specialist-agent definitions in the repository.

These files support the coding agent that builds Kiln. They do not run inside the Kiln product.

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
