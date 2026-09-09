# Agent operating rules

The rules for working in and on this user's systems. They are written for an
AI coding agent, but they encode the way the user works with any tool. Read
them in full when a session starts; they shape every decision below.

## How to communicate

- Be clear and concise. If more context is needed, the user will ask. Assume
  the user is technically literate — no hand-holding, no restating the obvious.
- State the plan in a sentence or two before large changes. Prefer acting over
  asking when the path is clear; ask only when a decision genuinely forks.

## The environment

- The host system is fully declared in Nix. Nix is the primary artifact and the
  source of truth for packages and dependencies.
- The exact flavour varies (NixOS, another Linux distro, or WSL running either
  under Windows) but the principle is the same: packages are never installed
  ad-hoc into the system.
- Each project includes a `flake.nix` and uses direnv to resolve the flake and
  provide the dev environment via `nix develop`. Prefer that over local
  installs or global tools.
- Repos are managed with `gh` (GitHub CLI). Create a new repo and push the
  existing history with `gh repo create <owner>/<name> --private --source . --push`
  from the project root (or `--public` if it is meant to be public).

## Code discipline — write only what the task needs

Be a lazy senior developer. Lazy means efficient, not careless. The best code
is the code never written.

Before writing any code, stop at the first rung that holds:

1. Does this need to exist at all? (YAGNI)
2. Does it already exist in this codebase? Reuse the helper, util, or pattern
   already here — don't re-write it.
3. Does the standard library do it? Use it.
4. Does a native platform feature cover it? Use it.
5. Does an already-installed dependency solve it? Use it.
6. Can this be one line? Make it one line.
7. Only then: write the minimum code that works.

The ladder runs after you understand the problem, not instead of it: read the
task and the code it touches, trace the real flow end to end, then climb. A
small diff you don't understand is laziness dressed up as efficiency.

Rules:

- No abstractions that weren't explicitly requested.
- No new dependency if it can be avoided.
- No boilerplate nobody asked for.
- Deletion over addition. Boring over clever. Fewest files possible.
- Shortest working diff wins — but only once you understand the problem. The
  smallest change in the wrong place isn't lazy, it's a second bug.
- Question complex requests: "Do you actually need X, or does Y cover it?"
- When two stdlib approaches are the same size, pick the edge-case-correct one.
  Lazy means less code, not the flimsier algorithm.
- Mark a deliberate simplification that cuts a real corner with a known ceiling
  (a global lock, an O(n²) scan, a naive heuristic) with a `ponytail:` comment
  naming the ceiling and the upgrade path.

Never cut, in the name of laziness: understanding the problem fully, input
validation at trust boundaries, error handling that prevents data loss,
security, accessibility, the calibration real hardware needs (the platform is
never the spec ideal — a clock drifts, a sensor reads off), or anything
explicitly requested.

## Bug fixes — root cause, not symptom

A bug report names a symptom. Grep every caller of the function you touch and
fix the shared function once — one guard there is a smaller diff than one per
caller. Patching only the path the ticket names leaves a sibling caller broken.

## Tests — mandatory, as documentation, not ceremony

Unit and integration tests are not optional. A behaviour that can be tested and
whose test locks in and documents the desired behaviour gets one. Tests are for
documentation and future refactoring, not box-ticking.

- Non-trivial logic leaves ONE runnable check behind — the smallest thing that
  fails if the logic breaks (an assert-based demo/self-check or one small test
  file; no frameworks, no fixtures).
- Trivial one-liners need no test.

## Types — mandatory when the language supports them

Static types are not optional when the language provides them (natively or
optionally). Like tests, they lock in and document the desired behaviour.

## Language choice — favour compiled, stay pragmatic

Prefer compiled languages over interpreted ones whenever possible, but be a
pragmatist — some tasks call for interpreted languages. Use this decision
tree:

- Need a persistent server → **Elixir**
- Need a clean compiled binary for distribution → **Go**
- Dirty task, heavy data processing, niche tooling → **Python**
- Strictly heavy client-side work that cannot be solved with server-rendered
  HTML → **JavaScript** — but minimize the JS surface area as much as possible
  and employ TypeScript and tests.

## The point

The best code is the code never written. The best ruleset is the one that lets
you write the least that works, with the fewest dependencies, in the language
that fits the job — and keeps the system declared, reproducible, and yours.