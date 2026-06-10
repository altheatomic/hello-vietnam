# Project Agent Instructions

Apply these instructions to all work in this repository unless a deeper `AGENTS.md` overrides them.

## Operating Principles

### 1. Think Before Coding

- Do not silently choose an interpretation when the request is ambiguous.
- State assumptions explicitly when they affect the solution.
- If multiple reasonable paths exist, surface the tradeoffs before committing.
- If something is unclear or risky, pause and ask instead of guessing.
- If a simpler solution would meet the goal, recommend it.

### 2. Simplicity First

- Write the minimum code that solves the actual problem.
- Do not add speculative abstractions, configurability, or future-proofing.
- Avoid introducing new dependencies unless they are clearly justified.
- Prefer existing project patterns over inventing new ones.
- If a solution feels overbuilt, simplify it before shipping it.

### 3. Surgical Changes

- Change only what is necessary for the task.
- Do not refactor, reformat, rename, or reorganize unrelated code.
- Preserve existing comments and documentation unless the task requires edits.
- Match the surrounding style, naming, and structure.
- Remove only dead code or imports created by your own changes.
- If you notice unrelated issues, call them out separately instead of fixing them opportunistically.

### 4. Goal-Driven Execution

- Define clear success criteria before making changes.
- Prefer work that can be verified with tests, builds, or targeted checks.
- For bug fixes, reproduce the issue first when practical, then prove the fix.
- For non-trivial work, keep a short plan and update it as you progress.
- Do not stop at “code written”; stop when the requested outcome is reasonably verified.

## Execution Defaults

- Start with the smallest useful change that can prove or unblock the direction.
- Read enough surrounding code to understand local conventions before editing.
- Keep diffs small, reviewable, and directly traceable to the request.
- Reuse existing utilities, components, and patterns before creating new ones.
- Do not broaden scope without a clear reason tied to the task.

## Validation

- Validate the narrowest relevant surface first, then expand if needed.
- Run the most targeted tests or checks available for the changed area.
- If no automated check exists, perform the best practical validation and say what was verified.
- Do not fix unrelated failing tests or broken tooling unless the user asks.
- If validation cannot be completed, explain the blocker clearly.

## Communication

- Be concise, direct, and transparent.
- Explain important tradeoffs, assumptions, and risks in plain language.
- Ask clarifying questions only when the answer materially affects the solution.
- When making an assumption to keep progress moving, say what you assumed.
- Present next steps or follow-ups only when they are useful and closely related.

## Safety and Scope

- Do not make destructive changes unless they are explicitly requested.
- Do not remove user work, generated files, or configuration without clear justification.
- Treat secrets, credentials, and environment-specific settings carefully.
- Prefer reversible edits over sweeping rewrites.

## Project-Specific Additions

- Add repository-specific rules below this section when needed.
- Examples: required test commands, code style constraints, forbidden directories, release steps, or ownership boundaries.
