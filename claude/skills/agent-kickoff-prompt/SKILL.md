---
name: agent-kickoff-prompt
description: >
  Generate a rigorous kickoff prompt for delegating an implementation task to a
  working (implementer) agent session, following a battle-tested 10-section
  pattern that reduces review churn. Use when asked to "write a prompt for the
  working agent", "kickoff prompt", "delegation prompt", or "prepare the agent
  brief".
---

# Agent kickoff prompt

Produce a single prompt handed to a fresh implementer-agent session. The pattern
below was refined across a multi-PR project and demonstrably cut review churn:
the agent plans against verified facts instead of re-deriving them, and design
disagreements surface at plan time, not in PR comments.

## Meta rules — before you send anything

1. **Verify everything.** Code moves faster than docs. Before sending, check:
   - issue/epic numbers against the tracker (`gh issue view N`),
   - package paths and API signatures against current `origin/main` (read the
     actual source, not docs),
   - doc section references against the actual doc (a prompt citing a
     nonexistent §14c degrades trust and wastes a full agent round-trip),
   - task/CI gate names against the Taskfile (`task --list`).
2. **Deduplicate ruthlessly.** Repeated blocks are token waste and confuse the
   agent about which instance is authoritative. Say each thing once, in the
   section where it belongs.
3. **State the key/idempotency/data model precisely.** E.g. "items are keyed by
   the composite (tenant, caller, request_id); re-delivery must be a no-op".
   Agents code against whatever model the prompt implies — vagueness here
   becomes a wrong schema.
4. **Demote anything design-contested** from a REQUIRED section to an Open
   Decision with a stated default. Never present a contested choice as settled.
5. **Include one line on what changed on main recently** that affects the task
   (renamed package, new shared helper, merged prerequisite PR), so the agent
   doesn't work from a stale mental model.

## Required sections, in order

Every generated prompt has these ten sections. Omit none; keep each tight.

1. **Identity + scope header** — what the agent is implementing, the EXACT
   tracking issue/epic numbers (verified, never guessed), and one line stating
   what is already merged/available so the agent doesn't stub things that exist.
2. **Worktree + branch setup** — exact `cd`/`git` commands to the prepared
   worktree and fresh branch off current main. Explicitly forbid creating new
   worktrees or building on stale feature branches. End with: "do not push or
   open a PR until I approve the plan".
3. **Read first, in order** — layered context:
   a. repo meta-docs (`REGISTRY.md`, relevant `AGENTS.md`),
   b. the project's running/planning doc, with specific section pointers,
   c. the spec,
   d. **the REAL dependency code**: exact package paths plus any known gotchas
      about its actual API — "do not re-derive from docs".
   Section (d) is the highest-value part of the whole prompt. Every factual
   claim in it must be verified against current main before sending.
4. **Scope** — the numbered algorithm/behavior, the invariants it must honor
   *by name*, and an explicit "this task does NOT do X" line.
5. **Open decisions — SURFACE these in your plan, do not silently implement** —
   2–4 genuinely undecided items. Each gets: enough context to reason about, a
   stated default where one exists, and an invitation to argue for an
   alternative. This section catches design errors before any code exists.
6. **Conventions — non-negotiable** — tight scoped PRs (shared-infra changes go
   in their OWN PR); clean code with no planning references in source (no spec
   section numbers, no "Phase-N", no "#NNNN will replace this"); reuse shared
   types, never redefine them; the workload shape (e.g. worker vs gRPC
   service).
7. **Cell/infra or deployment specifics** — mirror a named existing precedent
   cell/service; list known declared debts to replicate rather than
   re-litigate.
8. **Tests (scope)** — unit (table-driven, fakes) and integration (real backing
   stores, build tags), naming the specific behaviors that MUST be pinned:
   crash windows, races, idempotency, boundary cases.
9. **Verify before pushing** — the exact command list CI will run (build, vet,
   lint, unit, integration, infra-check, docs gates, precommit), with "show the
   output".
10. **Process** — plan first: restate acceptance criteria + file list +
    resolve/flag the open decisions, THEN WAIT for approval before coding. One
    logical change per commit, imperative messages, no AI attribution. PR
    description conventions incl. "Closes #NNN". The agent drives the
    automated-review loop (e.g. Greptile to 5/5); human-reviewer comments are
    left to the human.

## Worked example skeleton

Fill placeholders; delete lines that genuinely don't apply.

```text
You are implementing <TASK> — issue #<ISSUE#>, part of epic #<EPIC#>.
Already merged and available: <MERGED DEPENDENCY / SHARED PACKAGE> — use it,
do not stub or reimplement it.

## Setup
cd <WORKTREE PATH>   # prepared worktree — do NOT create a new one
git fetch origin && git checkout -b <BRANCH> origin/main
Do not build on stale feature branches. Do not push or open a PR until I
approve your plan.

## Read first, in order
1. REGISTRY.md and <DIR>/AGENTS.md
2. <PLANNING DOC> — sections <X> and <Y>
3. <SPEC PATH>
4. The real dependency code (do not re-derive from docs):
   - <DEPENDENCY PACKAGE 1> — note: <API GOTCHA>
   - <DEPENDENCY PACKAGE 2> — note: <API GOTCHA>
Recently changed on main: <ONE-LINE RECENT CHANGE THAT AFFECTS THIS TASK>.

## Scope
1. <STEP 1 OF ALGORITHM>
2. <STEP 2>
3. <STEP 3>
Invariants: <INVARIANT NAME 1>, <INVARIANT NAME 2>.
Data model: items are keyed by <EXACT KEY>; <IDEMPOTENCY RULE>.
This task does NOT do <EXCLUDED WORK>.

## Open decisions — surface these in your plan, do not silently implement
1. <OPEN DECISION 1> — context: <WHY UNDECIDED>. Default: <DEFAULT>. Argue if
   you disagree.
2. <OPEN DECISION 2> — context: ... Default: ...
3. <OPEN DECISION 3> — context: ... No default; propose one.

## Conventions — non-negotiable
Tight PR scope; <SHARED-INFRA CHANGE> goes in its own PR. No planning
references in source (no spec §, no Phase-N, no "#NNN will replace this").
Reuse <SHARED TYPES PACKAGE>; never redefine. Ship as a <WORKLOAD SHAPE>.

## Cell/infra
Mirror <PRECEDENT CELL/SERVICE>. Replicate its declared debts (<DEBT 1>,
<DEBT 2>) — do not re-litigate them.

## Tests
Unit: table-driven with fakes. Integration: real <BACKING STORE>, build tag
<TAG>. Must pin: <CRASH WINDOW>, <RACE>, idempotent re-delivery, <BOUNDARY>.

## Verify before pushing (show the output)
<BUILD CMD>; <VET/LINT CMD>; <UNIT CMD>; <INTEGRATION CMD>; <INFRA-CHECK CMD>;
<DOCS GATE CMD>; <PRECOMMIT CMD>

## Process
Plan first: restate acceptance criteria, list files you'll change, and
resolve or flag each open decision — then WAIT for my approval. One logical
change per commit, imperative messages, no AI attribution. PR description
follows repo conventions and includes "Closes #<ISSUE#>". Drive <AUTOMATED
REVIEWER> to a clean pass yourself; leave human reviewer comments to me.
```

## Output

Return the finished prompt in a single fenced block, ready to paste into the
implementer session. After it, list what you verified (issue numbers, package
paths, doc sections, task names) so the author can spot-check.
