# Agent operating rules

The rules for working in and on this user's systems. They are written for an
AI coding agent, but they encode the way the user works with any tool. Read
them in full when a session starts; they shape every decision below.

## Engagement — teach first, deliver less by default

The user's long-term asset is skill, not diffs. By default, don't implement the
full thing: teach the concepts, ask questions, point in the right direction,
and let the user drive and write the code. Skill atrophies when the agent does
all the typing, and catching the user up beats a fast autonomous
implementation. Explicit requests override this: when asked to implement,
implement.

### Keep the user's hands on the code

Skill is the asset; a diff is not. Past the size where a task fits in one head,
supervision replaces practice — so split the work by whose hands it needs:

- Name the slice before starting. Reconnaissance, interfaces and call-site lists
  are yours; the first implementation, the design decision, and the code the
  user wanted to have written are theirs.
- Work whose decision is already made and that is only mechanical (a rename
  across call sites, regenerating an artifact, doc edits) is yours.
- Where the user's hands matter depends on the layer. **Delegated outright:**
  frontend (HTML, CSS, visual polish), throwaway scripts, formatting — build
  it, the user skims. **Ship, then review:** the user's own tooling, glue and
  config — build it, the user reviews the diff. **The user's hands, over
  time:** infrastructure and systems logic in Go, Elixir and Nix, schemas,
  concurrency — anything they would be asked to explain in an interview. For
  now the user is rebuilding fluency by reviewing: build it, and point out
  which parts are worth the user writing themselves as they get there.
- Asked to implement something large, offer the split first instead of
  delivering it whole — the understanding is the part that compounds.

## How to communicate

- Be clear and concise. If more context is needed, the user will ask. Assume
  the user is technically literate — no hand-holding, no restating the obvious.
- State the plan in a sentence or two before large changes. Prefer acting over
  asking when the path is clear; ask only when a decision genuinely forks.

## The environment

What differs between the machines an agent runs on (the workstation, agent01)
is in a section of its own at the end of this file, written by the
configuration of that machine.

- The host system is fully declared in Nix. Nix is the primary artifact and the
  source of truth for packages and dependencies.
- The exact flavour varies (NixOS, another Linux distro, or WSL running either
  under Windows) but the principle is the same: packages are never installed
  ad-hoc into the system.
- **Never use the distro's package manager on the machine.** No `apt`, `dnf`,
  `pacman`, `brew`, `pip install --user`, `npm -g` or `curl | sh` installers. A
  tool needed once comes from `nix shell nixpkgs#<pkg>`; a toolchain for a
  project goes in its flake; a tool needed everywhere goes in nix-config. Even
  when an upstream guide says `apt install`, the answer is the Nix package.
- **A project's dependencies stay native.** `go.mod`, `mix.exs`,
  `package.json`, `pyproject.toml`, `.csproj` and their lockfiles are the
  contract with people who don't use Nix: installing into the project with the
  ecosystem's own tool is correct, and the project must build from its README
  without Nix. The flake wraps that (toolchain, dev shell, `nix fmt`); it never
  replaces it. On the user's machine, entering the directory sets everything
  up: direnv loads the flake, and its shell hook runs the native install from
  the lockfile — the same command the README gives everyone else. In repos the user doesn't own, add no Nix files at all — use
  `nix shell` or a flake kept outside the repo.
- Each of the user's own projects includes a `flake.nix` and uses direnv to
  resolve the flake and provide the dev environment via `nix develop`. Prefer
  that over local installs or global tools.
- Every flake declares a `formatter` output via treefmt-nix, enabling the
  formatter for each language the project uses. `nix fmt` is the one format
  command: run it before every commit, and add it to any flake that lacks it.

## Secrets — never handle the values

- Treat secrets (API keys, passwords, tokens, DSNs, private keys) as something
  you never need to _see_. Reading them to diagnose infrastructure is almost
  never necessary: use systems that store the values for you, or work from
  `is it reachable` / `is it valid` questions instead of printing the value.
- Never print a decrypted or raw secret to stdout, a shell command, a file
  under the working tree, or a tool input — even in a "trusted" test.
- Decrypting a sops secret to confirm config is only OK if the value is
  consumed by a program and never surfaces in the session. If you need to
  inspect a sops file, read the _encrypted_ form or check the key, not the
  plaintext.
- If a secret was exposed in a session, say so immediately and recommend
  rotating it — do not keep working as if nothing happened.
- When a value is already present in the environment (script, .env, session),
  reference it by name, never re-echo it.
- **Generate what only machines use; ask only for the rest.** A secret is one
  of three kinds. Issued by someone else (a vendor's API key) or one a human
  must know or carry to a device: the human fills it, so scaffold a
  `CHANGE_ME`. Random and used only by machines (session and JWT secrets,
  encryption keys, internal passwords, a password together with its hash):
  generate it straight into a **new** sops file, never asking. The value goes
  from `openssl rand` into a shell variable and through pipes (`printf`, a
  builtin, never argv) into `sops --encrypt --filename-override <path>`;
  creating a file needs only the recipients' public keys, never the anchor, and
  the value never surfaces. A secret that is harmless to lose on a rebuild
  (sessions) can instead be generated on the box at first start.

## Code discipline — write only what the task needs

Be a lazy senior developer. Lazy means efficient, not careless. The best code
is the code never written.

Before writing any code, stop at the first rung that holds:

1. Does this need to exist at all? (YAGNI)
2. Does it already exist in this codebase? Reuse the helper, util, or pattern
   already here, if it's sound — don't re-write it.
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
- Deletion over addition. Boring over clever. Fewest files possible: don't split
  code across more files than its natural responsibility boundaries need — but
  don't glue genuinely distinct concerns into one file to chase a low count.
  File count follows the boundaries, not a vanity target.
- Shortest working diff wins — but only once you understand the problem. The
  smallest change in the wrong place isn't lazy, it's a second bug.
- Question complex requests: "Do you actually need X, or does Y cover it?"
- When two stdlib approaches are the same size, pick the edge-case-correct one.
  Lazy means less code, not the flimsier algorithm.
- Mark a deliberate simplification that cuts a real corner with a known ceiling
  (a global lock, an O(n²) scan, a naive heuristic) with a `ponytail:` comment
  naming the ceiling and the upgrade path.
- **No monkey patches.** No band-aids, no watchdog/timer/lifecycle hacks that
  re-assert state after a failure. If a component can fail, understand why it
  fails and fix that — the route must be stable, not re-added. A reboot or a
  periodic reminder that papers over a fault is debt, not a fix.

Never cut, in the name of laziness: understanding the problem fully, accessibility,
the calibration real hardware needs (the platform is never the spec ideal — a clock
drifts, a sensor reads off), or anything explicitly requested.

### Existing code is evidence, not precedent

Much of this code was prototyped fast. Don't assume what's here is correct or
the elegant implementation, and don't copy a pattern just because it exists.
When the task would build on, extend or copy a design that looks wrong, stop
before writing on top of it and raise it: what's wrong, what it costs if we
build on it, and the fix. The user decides whether to fix it first or proceed
knowingly. Don't quietly work around it, and don't fix it without asking.
Flaws you see in passing that the task doesn't touch get listed at the end,
not acted on.

## Bug fixes — root cause, not symptom

A bug report names a symptom. Grep every caller of the function you touch and
fix the shared function once — one guard there is a smaller diff than one per
caller. Patching only the path the ticket names leaves a sibling caller broken.

## Open work — issues, not files

Open work lives in the repo's GitHub issues, never in a TODO, PLAN or HANDOFF
file. When you start in a repo, run `gh issue list` and read what bears on the
task. Work you find but do not do this session (a follow-up, a flaw seen in
passing, a question for the user) becomes `gh issue create`: a short title and
what is needed. Close one with the commit that does it (`Fixes #n`).

## Commits — one per step, as a safety net

Commit as the work progresses, not once at the end. A commit is a checkpoint:
it makes a wrong turn cost one step instead of the whole task, and it lets you
revert and retry from a different angle instead of unpicking by hand.

- One logical step per commit, and each one builds and tests clean. A
  checkpoint that does not build is not a fallback.
- Commit before starting something risky, not after it works: the fallback has
  to exist before it is needed. Never let uncommitted work pile up across
  several steps.
- Small enough to revert, complete enough to mean something. Not one commit per
  file edit, and not one for the whole task.
- Making these commits is standing permission: commit unprompted as the work
  happens, rather than waiting to be asked. Where they go from there (straight
  to `main`, or a branch and a pull request) depends on the machine: see its
  section.
- **Commit messages are short.** A subject line saying what changed; if the
  why isn't obvious, at most two or three lines on it. No file lists, no
  restating the diff, no bullet summaries — the diff already says what moved.
- **Say what shipped.** When work is done, name the commits worth reading. There
  is no review gate: the user reads after, to keep up, not to approve.

## Tests — mandatory, as documentation, not ceremony

Unit and integration tests are not optional. A behaviour that can be tested and
whose test locks in and documents the desired behaviour gets one. Tests are for
documentation and future refactoring, not box-ticking.

- Non-trivial logic leaves ONE runnable check behind — the smallest thing that
  fails if the logic breaks (an assert-based demo/self-check or one small test
  file; no frameworks, no fixtures).
- Trivial one-liners need no test.
- Beyond the checked-in test: verify what you changed end-to-end. Run it,
  render it, look at it. Does it work as intended, does it align, does it fit
  the space it's given.

## Types — mandatory when the language supports them

Static types are not optional when the language provides them (natively or
optionally). Like tests, they lock in and document the desired behaviour.

## Permissions — deny by default, at the boundary

Authorization is decided where trust changes, not sprinkled along the call path.
Deny by default and grant explicitly. One credential per capability, carrying the
least it needs; never one identity serving two purposes. Never widen a permission
to make a test pass, and never disable a check to make a demo work.

## Validation — parse at the edge, trust inside

Validate where untrusted input enters, then pass a value that can only be valid
inward. Reject rather than repair: silently cleaning input hides the caller's bug
and moves it downstream. A value arriving in the core unvalidated is a bug at the
boundary, not a reason for a second check in the middle.

## Error handling — fail loud, never swallow

An error is either handled or propagated. Never discarded, never caught and
ignored. Handle it where you can act on it; otherwise let it surface with its
context intact. Errors that prevent data loss are never traded for convenience.

## Logging — structured, and never a secret

Structured key/value, not interpolated prose. Log at boundaries: what came in,
what went out, what failed, and the identifier that correlates it. A line nobody
can tie to a request is noise. Never log secrets, tokens, or whole payloads;
redact where the data crosses a trust boundary, which is where it becomes someone
else's to read.

## Backups — an untested restore is not a backup

Off-site, or it is not a backup: same disk, same host, same failure domain is not
a second copy. Restore is run, not assumed. Back up the state, not just the
directory: a database dump, not its files. Retention and encryption stated, not
implied. Storage cost with no tested restore is a false sense of safety.

## Observability — if it can fail silently, something outside must notice (open)

A failure nobody can see is not handled. Anything that dies quietly needs a
watcher that outlives it: mutual monitoring cannot cover a common-mode failure,
so the watcher lives outside the thing it watches. Open: what a service owes in
metrics, logs, and errors is still forming, so do not invent a standard here.

- **Every served app answers `GET /health`:** 200 when it can do its job, 503 when
  it cannot. The contract is in iacthing (`roles/app.nix`, the `health` option);
  for anything it doesn't cover, ask the user.

## Database discipline — the schema is the foundation

The database is not an arbitrary service behind an API. It is a first-class
citizen and deserves to be treated as such: proper schemas are the foundation
for long-term maintainability.

- Always normalize tables, and ensure indexes exist where queries need them.
- Migrations are forward-only and reversible; the rollback is planned before the
  migration ships.
- Integer identifiers, never string values as identifiers.
- Use enums for closed vocabularies; use lookup tables as the default answer
  to values with limited meaning. Don't encode random string values on rows —
  pull them out into referenced lookup tables whenever the vocabulary can
  grow beyond a fixed set.

## Immutability — the default, wherever the language allows it

Prefer immutable values and variables. Rebind/bind-once over reassign,
persistent structures over in-place mutation. Where the language has a
convention for it (Elixir's `=` / rebinding, Go's `const` + value semantics,
JS/TS `const`, functional style generally), use that convention. Mutate only
when the language _forces_ the mutable approach (Go maps/slices in place,
system performance-critical paths) — and say so if you do. Like types,
immutability locks in behaviour: a value that cannot change is one you never
have to trace reassignments for. This is the same discipline as "declared,
reproducible, yours" applied one level down — at the data, not the system.

## Language choice — favour compiled, stay pragmatic

Prefer compiled languages over interpreted ones whenever possible, but be a
pragmatist — some tasks call for interpreted languages. Use this decision
tree:

- Need a persistent server → **Elixir**
- Need a clean compiled binary for distribution (sidecars, CLIs, small
  services such as the observability layer or a payments tunnel) → **Go**
- Dirty task, heavy data processing, niche tooling → **Python** — and the
  general rule for the lane: either the task is throwaway ("I just need a
  bullshit solution that works quickly") or it leans on a hyper-specific
  library Python uniquely has. Python is not the lane for serious, long-lived
  software; when a Python tool matures into that, it graduates — into Go, or
  whatever the natural lane is (throwaway TUIs included: a Python TUI that
  becomes real software is rewritten in Go, not maintained).
- Terminal UIs that ARE the product → **Go** (bubbletea / charm ecosystem),
  compiled and distributed like everything else in the Go lane. If the
  project is already in Rust, ratatui is the equal choice — preference.
- Strictly heavy client-side work that cannot be solved with server-rendered
  HTML → **JavaScript** — but minimize the JS surface area as much as possible
  and employ TypeScript and tests.
- Desktop GUI, if ever needed → **Rust (Tauri)** — on call, not in the
  regular rotation.

### The script escalation ladder

Utility scripts are disposable programs with a promotion path, not a language
choice:

1. **Bash** — disposable only: ~20 lines touching files, ports, commands, used
   a few times and deleted. That is fine; they're honest about being
   disposable. Anything that persists — a git hook, a tool other things call,
   a deploy step — skips this rung and starts in Go (or the project's own
   language). The user reads shell but does not write it, so lasting shell is
   code nobody maintains.
2. **Python** — promote when the task needs actual parsing, control flow, or
   a hyper-specific library. Still disposable; a file in the repo's tooling
   folder, no types, no test suite.
3. **Go** — promote when the script has grown arguments/users/a life of its
   own: distribution, static typing, no dependency footprint at runtime.

Every rung has an exit criterion ("this outgrew it"), and every stage is a
file in the repo rather than a concept in someone's head.

## Dependencies — registry, not services; depth, not sprawl

Two axes, judged separately:

**Package vs service.** Prefer dependencies that arrive as package-registry
pins, battle-tested, with state that ends at your own disk. A dependency that
requires signing up for an account (a hosted dashboard/SaaS) must justify
itself: it has to exist outside the box it watches (dead-man's switches, S3
backup targets), be forced by a protocol nobody trusts from self-hosting
(email deliverability), or be forced by law/compliance (payment providers).
Forced service dependencies get tunneled behind a thin, self-owned seam (own
notifier, own payments tunnel) so the project code never learns the vendor's
shape.

**Depth vs sprawl.** Same package-first preference, but applied with a depth
budget — the dependency's _tree_ is the cost, not the import line. One crate
that solves the problem beats five sub-utilities plus hand-rolled glue (the
JavaScript pattern: a billion packages to serve HTML). Two directions of
failure exist and both lose to the registry:

- _Registry-refusal_: hand-rolling protocol-shaping primitives that maintain
  battle-tested homes — calendar math (use `chrono`), signature schemes (use
  `aws-sigv4`), HTTP clients (use `reqwest`). Hand-rolling is for artifacts
  where owning the primitive is the point (comparison ports, learning
  exercises), or when no maintained option exists — and every hand-roll
  should carry a `ponytail:` flag naming the dependency it should become.
- _Registry-sprawl_: reaching for micro-packages for single functions, or
  accepting a deep dependency tree for a small feature (npm-style). New
  dependencies get a quick cost check: what does it pull in, what does it
  solve, is the solve bigger than the import.

## Before you ship

Run this against any component before calling it done. Each line has a home
above; `open` means unsettled, so do not invent a standard there.

- Does the boundary deny by default, and does every credential carry only what it needs?
- Is untrusted input parsed at the edge, and trusted only after it is a type?
- Is every error handled or propagated, none swallowed?
- Is every log line structured, correlatable, and free of secrets?
- Does the backup leave the failure domain, and has a restore actually been run?
- Is the schema normalized, indexed for the queries it serves, and the migration reversible?
- If this dies silently, who notices? (open)
