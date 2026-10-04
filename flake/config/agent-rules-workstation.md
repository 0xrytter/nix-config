
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
