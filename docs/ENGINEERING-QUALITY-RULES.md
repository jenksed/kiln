# Engineering Quality Rules

**Document type:** Reference

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document have the meanings defined by BCP 14 when they appear in uppercase.

These rules apply to technical documentation, implementation plans, requirements, task descriptions, architecture decision records, pull-request reports, and completion reports.

## 1. Language

Project text MUST follow the repository rules that are derived from ASD-STE100 principles.

A writer MUST:

- use one meaning for each technical term;
- use the same term for the same concept;
- use short, direct sentences;
- use active voice when the actor is known;
- put one primary instruction or claim in each sentence;
- state conditions before actions;
- use explicit nouns instead of ambiguous pronouns;
- remove filler, repetition, promotion, and conversational padding;
- define uncommon abbreviations before use;
- use concrete quantities, boundaries, and conditions when known.

A writer MUST NOT claim formal ASD-STE100 compliance unless the text passed a repository-approved compliance check and dictionary review.

A writer MUST NOT use `robust`, `seamless`, `comprehensive`, `scalable`, `intuitive`, `production-ready`, `properly`, or `successfully` unless the text defines the observable property represented by the word.

## 2. Document type

Each document MUST have one primary purpose:

- **Tutorial:** helps a learner acquire a skill.
- **How-to guide:** helps a capable user complete a task.
- **Reference:** describes facts, interfaces, commands, schemas, or configuration.
- **Explanation:** explains concepts, rationale, relationships, or trade-offs.

A document SHOULD NOT mix these purposes without clear section boundaries.

## 3. Requirements

Product and system requirements MUST use an Easy Approach to Requirements Syntax (EARS)-compatible statement when the syntax applies.

Use these forms:

```text
The <system> shall <response>.
When <trigger>, the <system> shall <response>.
While <state>, the <system> shall <response>.
Where <feature is enabled>, the <system> shall <response>.
If <unwanted condition>, then the <system> shall <response>.
```

Each requirement MUST:

- have one responsible subject;
- express one required behavior or constraint;
- be necessary;
- be unambiguous;
- be feasible;
- be independently verifiable;
- avoid an implementation prescription unless the implementation is a constraint;
- include measurable limits when limits affect acceptance.

Facts MUST NOT be written as requirements. Goals MUST NOT be represented as mandatory requirements.

## 4. Acceptance criteria

Behavioral acceptance criteria SHOULD use Given-When-Then.

- **Given** defines the initial observable state.
- **When** defines one action or event.
- **Then** defines an observable result.

Acceptance criteria MUST NOT use outcomes such as `works correctly`, `is handled properly`, or `performs as expected`.

Each acceptance criterion MUST identify observable evidence.

## 5. Epistemic discipline

Project reports MUST keep these categories separate:

- **Observed:** established through direct inspection or execution.
- **Inferred:** concluded from observed evidence.
- **Proposed:** recommended but not implemented.
- **Assumed:** accepted temporarily without verification.
- **Unknown:** not established by available evidence.

A report MUST NOT present an inference, proposal, assumption, or likely convention as an observed fact.

When a material fact is unknown, the report MUST write `Unknown` and identify the cheapest reliable verification method.

Model memory is not evidence.

## 6. Source authority

For user intent and desired behavior, use this precedence:

1. current user instruction;
2. accepted specification;
3. accepted architecture decision record (ADR);
4. current approved plan;
5. older project documentation.

For claims about the current system, use this precedence:

1. current command, test, or runtime evidence;
2. source code and configuration at the current commit;
3. generated artifacts from the current commit;
4. repository documentation;
5. version-matched official external documentation;
6. secondary external sources;
7. model memory.

When sources conflict, the report MUST identify the conflict. The report MUST NOT silently choose one source.

## 7. Evidence

Each material claim about the current repository MUST include at least one of:

- a repository path and relevant symbol or line range;
- an exact command and exit status;
- test output;
- a generated receipt or artifact;
- a runtime observation;
- version-matched official documentation.

A report MUST distinguish directly collected evidence from evidence supplied by another agent or an older report.

The words `implemented`, `fixed`, `working`, `complete`, `verified`, and `production-ready` MUST include the evidence that justifies the statement.

Code review is not execution evidence.

A passing test is evidence only for the behavior evaluated by that test.

The absence of an observed error is not evidence of correctness.

## 8. Implementation plans

Each implementation plan MUST contain:

1. objective;
2. observed current state and evidence;
3. assumptions and unknowns;
4. requirements;
5. proposed changes;
6. files or components expected to change;
7. acceptance criteria;
8. verification commands;
9. required completion evidence;
10. explicit exclusions.

A plan MUST distinguish current behavior from proposed behavior.

A plan MUST NOT invent files, interfaces, dependencies, user needs, constraints, or architecture decisions.

## 9. Architecture decisions

A material architecture decision MUST be recorded in an ADR.

Each ADR MUST contain:

- status;
- context;
- decision drivers;
- considered options;
- decision;
- consequences;
- evidence and assumptions;
- superseded decisions when applicable.

A contributor MUST NOT reverse an accepted ADR without identifying the ADR and recording a superseding decision.

## 10. Completion

A task is complete only when:

- its acceptance criteria are satisfied;
- its required verification was executed;
- the verification result is recorded;
- material failures and warnings are disclosed;
- the repository state matches the completion report;
- remaining unknowns and exclusions are stated.

If required verification cannot run, report the task as `implemented but unverified`. Do not report the task as complete.

## 11. Anti-slop rules

A contributor MUST NOT:

- restate the request unless clarification requires it;
- add generic benefits that the project does not support;
- add sections only to increase document length;
- repeat one conclusion in multiple forms;
- use marketing language in technical documents;
- invent quotations, citations, benchmarks, users, incidents, or consensus;
- describe ordinary implementation choices as novel or transformative;
- state that a design `ensures` an outcome without a mechanism and verification;
- hide uncertainty with passive voice or vague wording;
- turn every observation into a recommendation;
- turn every recommendation into a requirement.

Prefer omission over unsupported content.

## 12. Automated enforcement

Documentation changes SHOULD pass the repository prose-linting checks.

The repository uses Vale for deterministic checks where a rule can be expressed without model judgment.

Vale SHOULD check:

- approved terminology;
- forbidden filler and promotional terms;
- heading conventions;
- ambiguous or weak claims that match deterministic patterns;
- repository-specific language rules.

A model self-review does not replace deterministic linting.

Vale results do not prove technical accuracy, requirement quality, or ASD-STE100 compliance. Human or agent review MUST evaluate those properties against this document.