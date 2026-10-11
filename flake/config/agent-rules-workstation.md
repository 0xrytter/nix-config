
## On the workstation

This machine: the user's own, with the vault, Docker and their GitHub login.

- **Push to `main` directly** once the work is committed and checked. You run
  supervised here, with the user's own GitHub login, whose admin bypass of the
  rulesets is meant for this machine. Agents on agent01 never have it.
- Repos are managed with `gh` (GitHub CLI). Create a new repo and push the
  existing history with `gh repo create <owner>/<name> --private --source . --push`
  from the project root (or `--public` if it is meant to be public).
- Docker is available on the host. Spin up any image you need (services for
  tests, throwaway databases, etc.); prefer disposable containers bound to
  `127.0.0.1` on a non-default port, and remove them after.

### Leading DeepSeek through stubthing — when the user asks for it

When the user asks for the stubthing flow, you are the lead and DeepSeek on
agent01 does the volume. DeepSeek's cap is daily (unused capacity is lost);
yours is weekly and scarce. So you spend tokens on judgement and DeepSeek on
everything mechanical.

- **The split.** Yours: the audit, the spec, a brief per task, the final verify
  and the merge, and anything the user or a domain owner must decide. DeepSeek's:
  the code, the tests, rework, doc drafts.
- **The repo** needs a fork the agents' App can reach (`repothing lock` and
  `repothing agent allow`) and a clone at `~/src/<repo>` on agent01. A task's
  `repo` is that lowercase name.
- **A task** is a stubthing `add_task` with `repo`, moved to `ready`. Its body
  is the whole prompt, at most 500 characters, and the session has no MCP: the
  detailed brief lives in the repo, and the body points at it and names the exact
  commands and the stop ("ruff, commit, stop"). Brief the behaviour, not a
  helper: a helper carries rules the brief did not mean.
- **Release one task per dispatch pass** (30 s): two attempts on one repo in one
  pass race on `git fetch` (llmthing #7). Release in batches each hour: the
  provider's limit is a rolling hour and ends sessions with a 429, often with
  nothing done.
  Re-file a cut-off task fresh; a rework continues on its old branch.
- **Verify here, merge here.** agent01 has no copy of production data, so the
  suite against the real dump runs on this machine. A branch that fails goes
  back with a `REVIEW.txt` committed at its root on the fork (the failures and
  what to do), and a new task says to merge `origin/<that branch>` first:
  reopening the old task starts from agent01's local copy, which never sees the
  review (llmthing #8).
- **The state lives outside you:** stubthing (tasks, a handoff note), the brief
  in the repo, the fork's default branch. After a compaction, rebuild from them.

### No plaintext secrets at rest

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
  dotfile, no value in argv where a process list can read it — and
  `$(cat /run/secrets/x)` inside a command is argv too; pass a file
  (`--netrc-file`, `--password-file`) or a pipe. `sec` and `secfile`
  exist precisely so no consumer needs one.
- **A new credential goes in the vault** (`sops secrets/personal.enc.yaml`), not
  in a plaintext file that outlives the session.
- **Know which trust group you are editing.** A name can exist in two stores
  holding *different* values — the workstation's `github-token` is not the agent
  box's `github-token`. Never "sync" one to the other.
