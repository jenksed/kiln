# <WORK-ID>: <Objective>

**Document type:** Reference  
**Status:** Proposed | Accepted | In progress | Blocked | Complete  
**Branch:** `<class>/<work-id>-<purpose>`  
**Depends on:** None | <WORK-ID list>

## Objective

State one outcome for this work package.

## Observed current state

Use only direct repository, command, test, runtime, or version-matched documentation evidence.

| Observation | Evidence | Collected by | Date or commit |
| --- | --- | --- | --- |
| <Observed fact> | `<path:symbol>`, `<command>` exit `<status>`, or artifact | <actor> | <date or SHA> |

## Assumptions and unknowns

### Assumptions

- **<ASSUMPTION-ID>:** <Temporary assumption and reason>

### Unknowns

- **<UNKNOWN-ID>:** Unknown. Verify with <cheapest reliable method>.

## Requirements

Use Easy Approach to Requirements Syntax (EARS)-compatible statements when applicable.

- **<WORK-ID>-R01:** The <system> shall <response>.
- **<WORK-ID>-R02:** When <trigger>, the <system> shall <response>.

## Proposed changes

Describe proposed behavior. Do not describe proposed behavior as current behavior.

1. <Change>
2. <Change>

## Expected files or components

| Path or component | Expected change | Status |
| --- | --- | --- |
| `<path>` | <change> | Proposed |

Do not invent a path only to complete this table. Write `Unknown` when discovery is required.

## Acceptance criteria

- **<WORK-ID>-AC01**
  - **Given** <observable initial state>
  - **When** <one action or event>
  - **Then** <observable result>
  - **Evidence:** <required command, output, artifact, or runtime observation>

## Verification commands

```bash
<exact command>
```

State the expected exit status or output for each command.

## Required completion evidence

| Evidence ID | Acceptance criterion | Required evidence |
| --- | --- | --- |
| <WORK-ID>-E01 | <WORK-ID>-AC01 | <command output, test result, path, or artifact> |

## Explicit exclusions

- <Behavior or component that this work package does not include>

## Completion record

Complete this section before merge.

**Result:** Complete | Implemented but unverified | Blocked | Abandoned

### Acceptance status

| Criterion | Status | Evidence ID | Result |
| --- | --- | --- | --- |
| <WORK-ID>-AC01 | Pass | <WORK-ID>-E01 | <concise result> |

### Verification executed

| Command or check | Exit status | Evidence location |
| --- | --- | --- |
| `<command>` | `<status>` | <PR log, artifact, or report> |

### Failures and warnings

- None observed. | <failure or warning>

### Remaining unknowns and exclusions

- <unknown or exclusion>

### Repository state

- Commit: `<SHA>`
- Branch: `<branch>`
- Diff reviewed: Yes | No