# Herdr

Herdr is the terminal workspace manager the coding agents live in. One client
window drives the local machine and the fleet's agent box side by side: detach
without stopping work, and choose per task whether a pane runs here or there.

The trust split is the reason to bother. Panes started on the workstation run
with this machine's permissions and its sandbox. Panes started on `agent01` run
as a fenced service account with no deploy rights and no access to this
machine. Root on the box is the deploy door and never runs panes.

---

## 1. What is declared, and where

Nothing about herdr is installed by hand. Two repositories own the two ends, and
one piece belongs to neither.

| Thing | Owner | Declared as |
| --- | --- | --- |
| `herdr`, workstation | `nix-config` | `herdr` in `flake/modules/home/wsl2.nix` (from nixpkgs) |
| Herdr settings, workstation | `nix-config` | `flake/config/herdr.toml`, linked to `~/.config/herdr/config.toml` |
| `herdr`, box | `iacthing` | `pkgs.herdr` in `roles/agent.nix` |
| Worker account, keys, shell, codex | `iacthing` | `iacthing.agent`, set in `hosts/agent01/configuration.nix` |
| Machine profile | *neither* | `herdr machine add` — runtime state, per client host |

The last row is deliberate. A machine profile is registration state, like
`tailscale up` or `gh auth login`, not configuration. `config.toml` has no
`[machines]` section (herdr reports `unknown config section [machines]` and
ignores it), and `machine add` also prepares the remote server. So it is a
command you run once per workstation, not a line in a flake.

### Why the settings file is read-only

`~/.config/herdr/config.toml` is a store symlink, so herdr's own settings editor
cannot write it. That is the trade, and it is the point: change a setting in
`flake/config/herdr.toml` and run `bash wsl2/switch.sh`. `onboarding` is spelled
out in the file because it is the one key herdr writes on its own, and it must
never need a write.

Two consequences worth knowing:

- If a declared file has to replace a real one already on disk, the option needs
  `force = true` (as `herdr/config.toml` has), or the switch refuses instead of
  clobbering it. Standalone home-manager has no `backupFileExtension`, unlike
  the NixOS hosts.
- A new file in either repository is invisible to Nix until git knows about it.
  `git add -N <path>` is enough; a commit is not required.

## 2. Adding a machine

The workstation side is already done: `herdr` is in the package list and the
settings file is declared. Adding a box is one host edit, one deploy, and one
registration command.

### Step 1 — declare the worker account on the box (iacthing)

In `hosts/<name>/configuration.nix`, point the role at the operator key and the
mirrored workspace path:

```nix
let
  # One list, two doors: root for deploys, the agent account for herdr panes.
  operatorKeys = [
    "ssh-ed25519 AAAA... rytter@iacthing"
  ];
in {
  iacthing.sshPublicKeys = operatorKeys;        # root, for deploys

  iacthing.agent = {
    enable = true;
    sshPublicKeys = operatorKeys;               # the pane door
    workspaceMirror = "/home/rytter";           # same path on both ends
  };
}
```

`roles/agent.nix` then creates the account with bash as its shell, authorises
the keys, installs `codex`, `git` and `herdr`, seeds a codex config, and gives
the account the model credential from the sops store. The account's home is
`/var/lib/agent`.

Deploy it. `nixos-rebuild` is not on the WSL host, so it comes from a shell:

```bash
cd ~/src/iacthing
nix shell nixpkgs#nixos-rebuild -c \
  nixos-rebuild switch --flake .#<name> --target-host root@<name>
```

Rebuilding changes the box's system closure and restarts affected services, and
it may update the bootloader. It does not require the box to be idle, but it is
not a no-op.

### Step 2 — register the profile (workstation)

```bash
herdr machine add --label agent01 agent@agent01
```

Use `agent@`, not `root@`. Root is the deploy door; pointing herdr at it would
make every pane on that box a root shell, which is the opposite of the reason
the account exists.

The target is the tailnet name, not the public IP. It is what the rest of the
fleet uses, it survives the address changing, and the firewall already trusts
the tunnel interface.

### Step 3 — verify

```bash
herdr machine list            # label, target, session, enabled
herdr status                  # client and server versions
ssh agent@<host> 'herdr --version'
```

In the sidebar the machine appears as its own group, alongside Local. Switching
is the highlight-then-Enter navigation, or a click. New workspaces and panes
land on whichever machine is selected.

## 3. Versions

Both ends run herdr from nixpkgs — one build per repository, matched by pin.
Cross-machine commands (`herdr --machine <label>`) need the same version on both
ends, so bumping nixpkgs in one repository without the other leaves the pair
unable to talk.

```bash
# in both ~/src/nix-config and ~/src/iacthing
nix flake update nixpkgs
```

Updating only the `nixpkgs` input keeps the change to the pin that carries
herdr, rather than moving every input at once.

### Do not run `herdr update`

The binary is Nix-managed, so `herdr update` would drop a curl-downloaded copy
over it and leave the two out of sync with the flake. The same applies on the
box: if `machine add` ever offers to install or update herdr there, stop.
Replacing the pin is the whole update path.

### The running server is older than the binary

Updating the package changes the binary, not the server already running from the
old store path. `herdr status` reports this as `server_binary_stale: yes`, and
`--machine` forwards through the server, so it needs a restart to actually run
the new version. Restarting ends the panes that server owns, so do it from
outside herdr rather than from a pane inside it.

## 4. Things that will bite

- **Machine profiles are per client.** Each workstation registers its own; they
  are not shared through the repository.
- **Identifiers are per server.** `w1:p1` and an agent name like `reviewer` can
  exist on several machines at once. Selecting a machine changes where the next
  pane starts; it does not retarget commands already running elsewhere.
- **`workspaceMirror` mirrors the path, not the contents.** The repositories a
  pane may touch have to exist on the box, at the same path.
- **The codex credential is read, never printed.** `codex` on the box is a
  wrapper: it reads the sops secret into `OPENCODE_API_KEY` in the process
  environment and execs the real binary, so bare `codex` works in a pane the way
  `occodexN` works here. Anything already running as that account can read the
  file, so the wrapper is hygiene rather than a boundary.
- **fail2ban whitelists the tailnet**, because the firewall already trusts
  `tailscale0` wholesale and banning a peer only creates a way to lock yourself
  out. Public SSH stays protected.
