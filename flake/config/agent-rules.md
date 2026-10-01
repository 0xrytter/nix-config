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

- The host system is fully declared in Nix. Nix is the primary artifact and the
  source of truth for packages and dependencies.
- The exact flavour varies (NixOS, another Linux distro, or WSL running either
  under Windows) but the principle is the same: packages are never installed
  ad-hoc into the system.
- **Never use the distro's package manager.** No `apt`, `dnf`, `pacman`,
  `brew`, `pip install --user`, `npm -g` or `curl | sh` installers. A tool
  needed once comes from `nix shell nixpkgs#<pkg>`; a tool needed for a project
  goes in its flake; a tool needed everywhere goes in nix-config. Even when an
  upstream guide says `apt install`, the answer is the Nix package.
- Each project includes a `flake.nix` and uses direnv to resolve the flake and
  provide the dev environment via `nix develop`. Prefer that over local
  installs or global tools.
- Every flake declares a `formatter` output via treefmt-nix, enabling the
  formatter for each language the project uses. `nix fmt` is the one format
  command: run it before every commit, and add it to any flake that lacks it.
- Repos are managed with `gh` (GitHub CLI). Create a new repo and push the
  existing history with `gh repo create <owner>/<name> --private --source . --push`
  from the project root (or `--public` if it is meant to be public).
- Docker is available on the host. Spin up any image you need (services for
  tests, throwaway databases, etc.); prefer disposable containers bound to
  `127.0.0.1` on a non-default port, and remove them after.

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

### On this dev environment — no plaintext secrets at rest

Agents here run on a machine that holds **no plaintext credential on disk**.
Everything lives encrypted in `~/src/secrets` (the workstation's vault) and
`iacthing/secrets/<host>.enc.yaml` (the fleet), and one age anchor is pasted into
tmpfs per session by `unlock`. Work with that, never around it:

- **Fetch, never hardcode.** `sec <name>` returns a value; `secfile <name>`
  returns a tmpfs path. The old plaintext locations are gone
  (`~/.config/opencode/secrets/`, `~/.ssh/id_ed25519`, `~/.config/iacthing/*.key`),
  so a consumer still naming one is a **bug to fix, not a path to recreate**.
- **`sec` is the most sensitive command on this machine.** Never run `sec` or
  `secfile` on their own, to test them, or to see a value: call them only inside
  the command that consumes the value. To check a credential, ask whether it is
  reachable or valid (an API call's status code), never look at it.
- **Never touch the anchor or `secfile`'s output.** The file at
  `$SOPS_AGE_KEY_FILE` is the master key to every secret, and
  `$XDG_RUNTIME_DIR/secrets/` holds decrypted values: never read, list, copy or
  search either, whatever the reason. Only `unlock`, `sec` and `secfile` go there.
- **"anchor not unlocked, run `unlock`" is the human's step, not a bug.** Report
  it and stop. Never make it go away by writing the key, a copy of the anchor, or
  the decrypted value anywhere.
- **`~/.config/sops/age/keys.txt` must stay absent.** It is the path `sops` falls
  back to when `SOPS_AGE_KEY_FILE` is unset *or* wrong, so a copy there silently
  makes `unlock` decorative and puts the master key back on disk. Never create it.
- **Never materialise a decrypted value**: no `sops -d` written to a file, no
  `| tee`, no redirect into the working tree, no new `~/.config/<tool>/secrets/`
  dotfile, no value in argv where a process list can read it. `sec` and `secfile`
  exist precisely so no consumer needs one.
- **A new credential goes in the vault** (`sops secrets/personal.enc.yaml`), not
  in a plaintext file that outlives the session.
- **Know which trust group you are editing.** A name can exist in two stores
  holding *different* values — the workstation's `github-token` is not the agent
  box's `github-token`. Never "sync" one to the other.

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

## Bug fixes — root cause, not symptom

A bug report names a symptom. Grep every caller of the function you touch and
fix the shared function once — one guard there is a smaller diff than one per
caller. Patching only the path the ticket names leaves a sibling caller broken.

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
  happens, rather than waiting to be asked. Pushing stays gated — local
  checkpoints are yours to make, the remote is not.
- **Review stamps are the user's alone.** A pre-push hook refuses any commit
  without a review stamp (a git note under `refs/notes/reviewed`), and the stamp
  is the user's one-line summary in their own words — it is how they keep their
  hands on what ships. Never run `git stamp`, never write to
  `refs/notes/reviewed`, never set `stamp.skip`, never push with `--no-verify`.
  When work is done, say which commits are waiting for review.

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
