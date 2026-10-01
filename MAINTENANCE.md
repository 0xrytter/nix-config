# Maintenance

## Open problem: pins age silently

`nixpkgs` is pinned at `ed67bc86e84e` (2026-05-06). As of 2026-09-18 that pin is
four and a half months old, and nothing in this repo notices or reports that.

Versions actually in play today:

| component | in use | notes |
|---|---|---|
| nixpkgs pin | 2026-05-06 rev `ed67bc86e84e` | 4.5 months old |
| herdr | 0.9.1 | WezTerm `default_prog` as of 2026-09-27; workstation and agent01, both from nixpkgs |
| tmux (nix) | 3.7c | still the multiplexer on the NixOS hosts (alacritty); no longer booted on WSL2 |
| tmux (distro) | 3.4 | Ubuntu's `/usr/bin/tmux`, the WSL2 emergency fallback |
| crush | 0.65.3 | pins bubbletea v2.0.6 |
| crush95 | 0.95.0, built from source here with four patches | the only client the deployed agent box will talk to |
| codex | 0.154.0 | nixpkgs; custom OpenCode Go provider |
| goose | 1.51.0 | llm-agents input, not nixpkgs (see below) |
| WezTerm | 20240203-110809 | `wezterm.exe` on Windows, outside nix, oldest thing here |
| fish / nvim | 4.6.0 / v0.12.2 | fine |

Two costs paid in the 2026-09-17/18 debugging session:

- **tmux 3.6–3.6b shipped a cursor-colour leak.** `prompt-cursor-colour` defaulted
  to colour 6 and was cleared with `OSC 112`, which some terminals don't
  implement; fixed in 3.7 by dropping the default (`tmux#4759`, commit
  `ce7eb22`). A fresher pin would have had that already.
- **Version numbers are not proof.** bubbletea PR #1526 ("ensure we reset cursor
  style and color on close", merged 2025-10-30, shipped v2.0.0) is exactly the
  fix for the cursor-colour leak, yet the bubbletea v2.0.6 vendored into crush
  0.65.3 still carries the frame-dependent guard in `cursed_renderer.go`. When
  judging a bump, read the code path, not the release note.

And an orthogonal trap that updating packages does **not** fix: **which binary is
the entry point.** A bare `tmux` in WezTerm's WSL `default_prog` resolved to the
distro's `/usr/bin/tmux` 3.4 as the *server* (which then outlives every WezTerm
restart), while an interactive fish shell resolved the nix 3.6a as the *client*.
Plugin `run-shell` commands inherit the server's environment, so they called the
3.4 client, hit a client/server mismatch against the 3.6a server, and failed
silently: the status line lost its gruvbox colours and every plugin keybind
disappeared. Pin the entry point, not just the package.

The same trap now applies to herdr, which is the WSL2 entry point: a bare
`herdr` would not be found at all there, because WezTerm's WSL domain inherits
the distro PATH, which has no nix profile. That is why `wsl2/wezterm.lua` names
an absolute path inside a login shell.

## What exists today

- `flake.lock` + `update.sh` — `nix flake update` + `nixos-rebuild switch`
  (NixOS hosts only, needs sudo).
- `update-npm-pkgs.sh` — bumps npm-derived packages in `flake/pkgs/`.
- `home.sh` — WSL home-manager switch. Does **not** update the flake, so the WSL
  side never picks up new pins.
- No cadence, no automation, no post-bump verification.

## Options (undecided)

1. **An update path for WSL**, e.g. `update.sh --home` or `update-wsl.sh`:
   `nix flake update --flake ./flake` then
   `home-manager switch --flake ./flake#wsl2`.
2. **Automatic bumps** — Renovate (or `nix-update` driven from CI) opening a PR
   on a schedule, so pin age is visible instead of discovered mid-debug.
3. **A post-bump smoke check**, so a regression shows in a minute instead of
   during an unrelated debugging session. Every line below has bitten us:
   ```sh
   herdr --version                             # client binary
   herdr status                                # running server, and is it the same build?
   herdr machine list                          # saved machines still resolve?
   herdr config check                          # the declared config parses?
   crush --version; fish --version; nvim --version
   ```
4. **Track the non-nix components explicitly** — WezTerm is a Windows install
   (`C:\Users\Rytter\.wezterm.lua`, canonical copy in `wsl2/wezterm.lua`), bumped
   by hand and re-synced; its `default_prog` is what boots herdr, so the two
   copies must stay identical.
5. **Keep the version table above current** whenever a bump lands.

## Cleanup backlog (deferred, collected 2026-10-01/02)

The repo works but needs a large cleanup; deliberately not started, small items
first. Known so far:

- **The NixOS hosts are legacy and do not evaluate.** DIY-Desktop, T480 and
  patrick-desktop all fail on `gtk.gtk4.theme`, defined by both stylix and
  `modules/home/common.nix`. Desktops run Nix on another distro now, so these
  are to be deleted or archived (patrick-desktop's user may want a fork).
  Verify changes against `homeConfigurations.wsl2` until then.
- **`rebuild.sh` is NixOS-only** and sits at the top level, easy to run on WSL2
  by mistake (`nixos-rebuild: command not found`). Goes with the hosts.
- **Shell embedded in Nix strings.** `sec`, `secfile` and `unlock`
  (`modules/home/secrets.nix`), `cclaude` and `start-session`
  (`modules/home/wsl2.nix`) are `writeShellApplication` scripts written inline,
  full of `''${` escapes and invisible to shell tooling. Move each to its own
  `.sh` file under `flake/config/` and load it with `builtins.readFile`, as
  `git-stamp` already is.
- **`repothing` is not on PATH**, so `repothing check` needs `go run`.
- **nvim's cursor is hard to see in insert mode** (noted 2026-10-02). Not yet
  diagnosed; possibly related to the cursor colour/shape notes under Loose ends
  below (OSC 12, the multiplexer relaying it). Collect when it happens: which
  terminal, inside herdr or not, after which program ran.

Not part of the cleanup, a small item on its own: `gh` keeps a plaintext token in
`~/.config/gh/hosts.yml`. The fix is in `~/src/secrets/AGENT-SANDBOXING.md`.

## Changes made 2026-09-29 (git hooks strip AI attribution)

Any harness that stamps a commit now gets its stamp removed, in one place,
instead of the trailer having to be defeated once per tool and once per
repository.

| file | change | why |
| --- | --- | --- |
| `flake/config/git-hooks/commit-msg` (new) | the stripper; executable, so the link farm keeps the bit | it matches the **shape** of the stamp — git trailer keys, plus the `Generated with [..](..)` body line — not harness names. A name blocklist rots as harnesses appear and misses silently when it does; trailer keys are a convention every harness copies, so there is nothing to port when the tool changes |
| `flake/modules/home/common.nix` | `programs.git.hooks.commit-msg` | one `core.hooksPath` covers every repository on the box, including ones not cloned yet, with nothing installed into a `.git/hooks` to drift. Do not also set `settings.core.hooksPath`: home-manager merges both into `iniContent` at equal priority, so declaring both is an evaluation error rather than a silent winner |
| `flake/config/claude-settings.json` | `"attribution": false` | the only lever that reaches a **pull request description**, which no local git hook can; it also covers the commit trailer |

Three things worth remembering:

- **Setting `core.hooksPath` disarms Claude Code's own attribution hook.** Its
  runner installs a hook to add the trailer, but skips that install when
  `core.hooksPath` is already set (`skipping Co-authored-by hook install so
  existing hooks keep running`). Declaring ours therefore wins by construction
  instead of fighting a per-session install.
- **The hook filters with `grep`, not `awk`.** `awk -v` puts the pattern through
  string escape processing, so `\(` reaches the regex engine as a bare `(` and the
  hook dies with `invalid regexp: unbalanced (` — which, under `set -e`, *aborts
  the commit*. The first revision had exactly this, and only driving a real
  `git commit` through the built artifact exposed it; testing the source file did
  not.
- **`attribution: false` needs claude-code >= 2.1.281.** Below that the whole
  settings file is rejected and the statusLine and Stop hook go with it. Every
  host carries 2.1.281 from the shared pinned nixpkgs, which is why the bare
  `false` is safe here rather than the lengthier `commit`/`pr`/`sessionUrl` form.

The trade-off, taken deliberately: a **human** `Co-Authored-By` is stripped too.
Without a name list there is nothing to maintain and nothing to miss, but the
trailer can no longer record a human co-author.

Not covered: `--no-verify`, commits made through the GitHub web UI, and commits
from a machine without this profile. Those want the server-side rule — a ruleset
`commit_message_pattern` with `negate` — which is not in place.

Not yet active: `bash home.sh` applies it. The hook logs what it stripped to
stderr, so a harness stamping in a shape the pattern misses shows up as silence
rather than failing quietly.

## Changes made 2026-09-27 (herdr replaces tmux as the WSL2 entry point)

WezTerm on Windows now boots straight into herdr. tmux is deliberately **not**
removed: `programs.tmux` lives in `flake/modules/home/common.nix`, which the
NixOS hosts share, and their alacritty still launches it. Retiring it there is a
separate decision.

| file | change | why |
| --- | --- | --- |
| `wsl2/wezterm.lua` (+ `C:\Users\Rytter\.wezterm.lua`) | `default_prog` -> `exec /home/rytter/.nix-profile/bin/herdr`; dropped the `Ctrl+Space` -> NUL binding | herdr's default prefix is `ctrl+b`, which needs no translation; the NUL mapping existed for tmux's `C-Space` prefix. The leader key is left at its default on purpose, to get a feel for it first |
| `flake/config/herdr.toml` (new) | declared config, linked to `~/.config/herdr/config.toml` | herdr's settings are Nix-owned now. The store symlink is read-only, so the in-app editor cannot save and the file is the source of truth. `onboarding` is spelled out because it is the one key herdr writes by itself |
| `flake/modules/home/wsl2.nix` | `herdr` package plus the config link; see `wsl2/HERDR.md` | one owner per end: this repo owns the workstation, iacthing owns the box |
| `flake/flake.lock` | `nixpkgs` bumped to `74435dcd` (2026-09-26) | herdr 0.9.1, which both ends need for `--machine` forwarding; the same bump landed in iacthing's lock |
| `wsl2/FINISH.md`, `wsl2/README.md`, `README.md`, `wsl2/switch.sh` | tmux references replaced | the entry point, the smoke checks, the verify step and the tool lists all described tmux |

The agent box changed in the same session, in iacthing: `roles/agent.nix` became
the herdr worker account (bash shell, operator key, codex wrapper, seed-once
codex config, `/var/lib/agent`), the crush server was unwired, and fail2ban now
ignores the tailnet range.

Not yet verified: whether herdr needs equivalents of the tmux workarounds that
fell out of the boot path. The OSC 52 clipboard settings and the cursor-colour
ban in `programs.tmux` are tmux-specific, and herdr is the multiplexer now — but
nothing has been measured against herdr, and the tmux config that carried them
is still in place for the NixOS hosts.

## Changes made 2026-09-24 (reaching the fleet from this machine)

The iacthing boxes answer for their applications on the tailnet and nowhere else, so
this machine had no route to any of them. It has one now, plus one word to use it.

| file | change | why |
|---|---|---|
| `flake/modules/home/wsl2.nix` | `tailscale` in `home.packages` | the client arrives with the profile instead of an installer script |
| `wsl2/tailscaled.service` | the unit, kept in this repository | it creates a tun interface, so it needs root - and home-manager owns no system services on Ubuntu |
| `wsl2/tailscale-setup.sh` | links the unit, starts it, joins the tailnet, then hands the node to `$USER` | one command and one password prompt for a fresh machine; after the operator flag no tailscale command needs sudo or a full path |
| `flake/modules/home/wsl2.nix` | `agent` fish launcher: `CRUSH_CLIENT_SERVER=1 crush95 -H tcp://agent01:7799` | `CRUSH_CLIENT_SERVER` is what selects client/server mode - without it `-H` is ignored and the agent runs locally, which reads the local filesystem and looks fine; the box runs the patched 0.95.0, so the client must be the same build, and no key is involved because the credential and the work stay on the box |
| `wsl2/README.md` step 9, `wsl2/FINISH.md` step 3 | the setup and the fresh-machine checklist | so the next machine gets this from the docs |

Two things worth remembering:

- **`crush` and `crush95` are different animals.** 0.65.3 is the packaged one, for
  local harness work. 0.95.0 is built from source here with the two cancel/render
  patches and is the only client that can talk to the deployed server, because the
  wire protocol is not stable between releases.
- **MagicDNS works without touching `/etc/wsl.conf`.** tailscale rewrites
  `resolv.conf` when it starts, which is what makes `agent01` resolve; the WSL
  regeneration only matters if it ever wins that race after a distro restart, and
  `generateResolvConf = false` is the fix if it does.

## Changes made 2026-09-18 (codex + goose on OpenCode Go workspace keys)

| file | change | why |
|---|---|---|
| `flake/modules/home/opencode.nix` | `codex` + goose in `home.packages` (goose from `agents.goose-cli`, llm-agents 1.51.0); `~/.codex/config.toml`, `~/.config/goose/config.yaml`; generic `occodex`/`ocgoose` fish launchers plus generated `occodex1..5`/`ocgoose1..5` shorthands mirroring `occgo`; default model `opencode-go/deepseek-v4.1-flash` in the opencode profiles and crush `models.large/small` | both new harnesses ride the same go-workspace keys as crush: codex via `OPENCODE_API_KEY` (`env_key` in config.toml), goose via its native `opencode_go` declarative provider |

Two pinned-version traps hit during this:

- **codex 0.154 dropped `wire_api = "chat"`** — custom providers must use
  `wire_api = "responses"`. The Go gateway accepts Responses-API requests for
  `deepseek-v4.1-flash` even though its docs list the model under
  chat/completions (verified with a real request).
- **goose-cli 1.47.0 (nixpkgs pin, 2026-05-06) cannot send `x-opencode-session`**
  for declarative providers — the per-provider `session_id_header_override`
  (bundled `opencode_go.json` on upstream) landed after it. The gateway 400s
  without that header, so goose comes from the `llm-agents` flake input
  (1.51.0) instead of nixpkgs. With 1.51.0 the provider works as configured:
  `GOOSE_PROVIDER: opencode_go` only.

Launcher env contract: `occgo1..5`/`occodex1..5` export `OPENCODE_API_KEY`,
`ocgoose1..5` export `OPENCODE_API_KEY` too (goose's `opencode_go` provider
reads that name). Keys live in `~/.config/opencode/secrets/go-workspace-N.key`;
workspaces 3-5 have no keys yet.

Follow-up same day: codex also needs `~/.codex/config.toml` to be a **real
writable file**, not a hm store symlink — it persists directory-trust entries
into the file and errors ("fails to trust directory / failed to persist")
otherwise. The config is now installed once by the `installCodexConfig`
activation step (skipped if the file exists); editing the declared model later
means deleting `~/.codex/config.toml` to re-seed. Goose's config hit the same
class of failure with a different shape: its own config writer resolves the
write target allowing at most **one** symlink hop (`MAX_SYMLINK_HOPS` in
`config/base.rs`), while a home-manager link is a two-hop chain, so
`~/.config/goose/config.yaml` is also a real writable file installed once
(`installGooseConfig` activation step; delete to re-seed). Goose's "too many
symlink levels" right after a switch was a stale shell PATH pointing at the
removed home-manager generation; a fresh shell fixes it.

## Changes made 2026-09-18 (Zellij swap, Catppuccin, tmux/pi removal)

tmux is out and Zellij is in, on the WSL side only. The tmux work above is
superseded by the swap — the cursor-colour leak cannot occur under Zellij (it
does not implement `set_background_color` / `set_foreground_color` /
`set_cursor_style` at all, so an app's `OSC 10/11/12` is dropped rather than
relayed), and the key collisions are Zellij's own config surface now.

| file | change | why |
|---|---|---|
| `flake/modules/home/wsl2.nix` | `zellij` in `home.packages`; `xdg.configFile."zellij/config.kdl"` with `theme "catppuccin-mocha"` and `session_serialization` | Zellij ships Catppuccin as a built-in theme (the KDL embedded in the binary uses the project's own palette — `#cdd6f4` text on `#181825`, peach/sky/green/pink emphasis), and serialization is its built-in resurrect/continuum equivalent — no plugin manager needed. Viewport serialization was deliberately left off: it copies every pane's scrollback on each tick and shows up as interactive stutter |
| `wsl2/wezterm.lua` (+ Windows copy) | `default_prog` now execs `zellij`; the hand-mapped `config.colors` table (gruvbox, then a base16 Catppuccin translation of it) replaced by `config.color_scheme = "Catppuccin Mocha"` | WezTerm bundles the upstream catppuccin/wezterm port as a built-in scheme, so the palette comes from Catppuccin rather than from hex values re-typed here; the base16 translation had ANSI black set to the background (`#1e1e2e`), which is why dim black text disappeared. stylix only themes the NixOS hosts and cannot reach a Windows-side WezTerm, so this file stays the source of truth for the terminal palette |
| `flake/modules/home/neovim.nix` | `colorschemes.gruvbox` → `colorschemes.catppuccin` | nvim ships its own colourscheme (stylix's neovim target is disabled in `common.nix`), so it needs the switch explicitly |
| `flake/modules/nixos/stylix.nix` | base16 scheme → `catppuccin-mocha.yaml`, generated wallpaper canvas `#282828` → `#1e1e2e` | flips the NixOS hosts (all stylix-managed apps) to Catppuccin; WSL has no stylix, so this is desktop-only |
| `flake/modules/home/common.nix`, `flake/hosts/wsl2/home.nix`, `flake/users/rytter/home.nix`, `flake/flake.nix` | removed `programs.tmux`, the tmux plugins block, the `tmux-gruvbox` input and its `extraSpecialArgs`, the `tmr` abbreviation | tmux is replaced by Zellij; `/usr/bin/tmux` (distro 3.4) remains as an emergency fallback, and the old config is recoverable from git history |
| deleted | `flake/config/pi-gruvbox.json`, `flake/config/pi-extensions/`, `flake/config/tmux/ai-status.py`, `flake/config/tmux/ai-dispatch.sh`; `agents.pi` dropped from `home.packages` | pi is not used any more, and the tmux status-line scripts have nothing to render into |

Still gruvbox on the machines (needs a decision or an asset):
`gtk.iconTheme` (`oomox-gruvbox-dark` / `gruvbox-dark-icons-gtk` — `catppuccin-cursors`
and `catppuccin-papirus-folders` exist in nixpkgs), and
`flake/modules/home/hyprland.nix`'s `swww img ~/Wallpapers/gruvbox-mountain-village.png`.

## Undecided: Zellij UI, bars off by default and a cheat-sheet on demand

Goal: nothing but the app on screen while working, with the keybinding hints
summonable on demand inside the session. Explored 2026-09-18; nothing built.

Outcome 2026-09-19: dropped in favour of tmux (see the 2026-09-19 change log
below); kept for the record.

Findings, recorded so they do not get re-litigated:

- No session-wide show/hide for the bars exists. There is no
  `ToggleStatusBar`/`ToggleView`; PR #4983 added one and was declined, with the
  maintainer pointing at `override-layout` (issue #694, open since 2021).
- `override-layout` is the sanctioned route but it re-applies a layout: existing
  panes get re-tiled and the arrangement is not remembered, so it is not a
  "hide the chrome for a second" key.
- `HideSelf` on a layout UI pane is a broken path: the tiles re-layout but the
  viewport offset is not recomputed, so gaps/ghost panes appear, and `ShowSelf`
  does not restore the `size=1 borderless` slot. Issues #2949 and #5098. Do not
  build on this.
- `ToggleFocusNoUiFullscreen` hides everything, but only for the focused pane;
  useless once a tab has more than one pane.
- Bar *looks* are the cheap axis and orthogonal to hiding: zjstatus is a drop-in
  compact-bar replacement, and a bespoke bar is a few hundred lines of Rust to
  wasm (`zellij:compact-bar` is 528 LOC). Looks are not the hard part.

The compromise worth trying: no bars by default, hints as a floating pane.

- `default_layout` pointing at a custom bars-less layout, with a
  `default_tab_template { children }` so new tabs are bars-less too (shape from
  upstream discussion #4991).
- A keybind that launches a bar plugin as a *floating* pane pinned to the bottom
  row (x=0, y=rows-1, width=100%, height=1, borderless), dismissed with
  `ToggleFloatingPanes`.

Why this is not the plugin route that already failed: it never calls `hide_self`.
The bar is a float, and float visibility is a first-class toggle, so it avoids the
broken suppress path entirely.

Unknowns to test before committing:

- does the stock `zellij:compact-bar` behave when launched floating (it calls
  `set_selectable(false)` and assumes a 1-row pane), or does this need a small
  plugin that positions itself via `change_floating_panes_coordinates`?
- does a floating bar track mode/tab changes the way the docked one does?
- `ToggleFloatingPanes` is per tab and toggles *all* floats in it, so any other
  floating pane would come and go with it.

Fallbacks: dock the compact bar and eat one row, or zjstatus for looks (still not
hideable).

## Changes made 2026-09-19 (tmux restored, Catppuccin + OSC 52 clipboard)

The un-hideable Zellij bar (above) lost to "just use tmux": tmux's status line is
a runtime option, so it can be toggled, and its key tables give the modal
structure without a wasm plugin. WezTerm's `default_prog` is back to tmux; zellij
stays installed but is not the default.

| file | change | why |
|---|---|---|
| `flake/modules/home/common.nix` | `programs.tmux` restored (recovered from `fe169a4^`), `tmuxPlugins.catppuccin` in place of the old `tmux-gruvbox` input | the config was only dropped in `fe169a4`, so it comes back from git; Catppuccin matches the rest of the theme and needs no new flake input |
| `flake/modules/home/common.nix` | `set -g set-clipboard on`, `set -g allow-passthrough on`, `Ms` override in `terminal-overrides` | opencode emits `OSC 52` itself and also wraps a copy in a tmux passthrough DCS (`wy()` in its bundle). `set-clipboard on` accepts the raw sequence, `allow-passthrough on` lets the wrapped copy reach WezTerm, and `Ms` lets tmux emit `OSC 52` too. WezTerm owns the Windows clipboard |
| `wsl2/wezterm.lua` (+ `C:\Users\Rytter\.wezterm.lua`) | `default_prog` -> `tmux new-session -A -s main` | tmux is the intended multiplexer again; Ctrl+Shift+Z still opens a bare no-multiplexer window |

The `Ms` override must be a **single** backslash in the generated conf
(`\E]52;...\007`): tmux's `show-options` prints values raw, so a doubled
backslash is stored literally and never becomes `ESC`. Verified against the
generated conf with `show-options -gv terminal-overrides`.

The Catppuccin **status line** is a separate step from the theme. v2 declares its
modules as `@catppuccin_status_<name>`, and they only exist once the plugin has
loaded, so `status-left`/`status-right` must reference them afterwards, while
`@catppuccin_flavor` and the window options must be set before it. That is why
home-manager emits each plugin's `extraConfig` immediately before its
`run-shell` and the main `extraConfig` after all of them: palette + window
options go in the plugin block, status declarations in the main one. Getting the
order wrong leaves the colours applied but the bar on tmux's stock segments,
which is exactly what the first pass did.

The module list is catppuccin's README "Recommended Default Configuration" (the
one the previews are generated from), minus `cpu` and `battery`: `application`,
`session`, `uptime` on the right, nothing on the left. Both dropped modules come
up empty on WSL (no battery, and the cpu sampler reads nothing here), so they
only added blank segments; their `cpu`/`battery` plugins went with them. Also
took the README's `default-terminal "tmux-256color"` (its terminfo is present on
this box).

Auto-restore was turned off too. resurrect's `restore.sh` ran on every server
start and replayed the last save, which was from 2026-09-18 (the pre-zellij
layout), so every launch opened a stale 10-window session instead of a clean one
and it read as if the new status line had not applied. Saving stays on
(continuum, 5 min) and restoring is manual (prefix + Ctrl-r); the old saves were
moved to `~/.tmux/resurrect.bak-*`, and a fresh launch now starts with a single
window.

Two tmux socket/lifecycle traps found while chasing that, both of which present
as "the config didn't apply":

- this box's tmux server is at `/run/user/1000/tmux-1000/default`, not
  `/tmp/tmux-1000/default`: `TMUX_TMPDIR=/run/user/1000` is set in the WSL
  environment, so a `tmux kill-server` run without that variable hits the wrong
  socket and leaves the real server running.
- tmux reads its config once, when the *server* starts. A home-manager switch
  only rebinds `~/.config/tmux/tmux.conf`, so a server started before an edit
  keeps the old look (here: the theme from 13:08, before the status modules
  existed) until it is killed.

Discoverability: `tmuxPlugins.tmux-which-key` added in XDG mode, menu on
`prefix + Space` (`C-Space`, then `Space`), config at
`flake/config/tmux/which-key.yaml` (upstream's `config.example.yaml` minus the
TPM submenu, with the reload macro pointed at `~/.config/tmux/tmux.conf`). Two
nix-specific wrinkles, both of which fail loudly only at runtime:

- the new config file needed `git add -N`: flakes only see git-tracked files, so
  the rebuild otherwise fails with a "not tracked by Git" error.
- the plugin first copies its *store* `init.example.tmux` into
  `~/.local/share/tmux/plugins/tmux-which-key/init.tmux`, and that copy inherits
  the store's read-only mode, so `build.py` then dies with `EACCES` and, under
  `set -e`, the `tmux source-file` that applies the menu never runs. An
  activation step pre-creates that file writable so the copy is skipped.

Note `prefix + Space` was previously tmux's default `next-layout`; the menu now
owns that key (layouts are reachable from the menu).

Two Catppuccin status-line quirks that present as "our config broke it". Both are
upstream, and both are corrected by overrides in `common.nix`:

- `message-style` / `message-command-style` take their background from
  `CTP_MESSAGE_BACKGROUND`, which expands `@catppuccin_status_background` and so
  becomes the literal string `default` (the terminal's base colour, not the bar's
  mantle), while the fg is `@thm_teal`, a colour used nowhere else. Prompts
  therefore land as off-colour text on a slightly-off band. Pinned to
  `fg=@thm_fg,bg=@thm_mantle,fill=@thm_mantle`: without `fill` tmux draws the
  prompt as a partial band across the status line, so it slices through whatever
  window pill sits beneath it; with `fill` it covers the full row and cleanly
  replaces the bar while it is up.
- `window-status-bell-style` / `-activity-style` set a whole-pill background, but
  `window-status-format` resets with `#[none]` immediately before the window
  number, so the number inherits the bell style: a yellow-on-crust slab inside a
  pill whose rounded notches are pinned to the bar colour, which reads as a
  glitched cutout. Fixed by leaving the background alone and recolouring only the
  number (`bg=default,fg=@thm_yellow` / `@thm_lavender`).

Not Catppuccin's business but visible in the same popups: fzf ships its own
default palette, colouring its pointer/marker/highlight with ANSI red, which
lands on Catppuccin red through WezTerm. The sesh popup (`prefix s`) runs fzf,
so it gets Catppuccin Mocha's official fzf palette via `FZF_DEFAULT_OPTS` set in
the tmux *server* environment (`set-environment -g`), because popups inherit
that, not the client's shell. Note `hl`/`hl+` stay Catppuccin red by design (that
is the matched-text highlight); only the pointer/marker change.

**Cursor colour, solved at the right layer.** `,*:Cs@:Cr@` in
`terminal-overrides` bans it outright. tmux relays an application's OSC 12 to
the terminal through the `Cs`/`Cr` capabilities, and since the cursor is device
state with no per-cell model it cannot scope that per pane, so an app that sets
it (or fails to reset it) strands the colour. Cancelling the capabilities stops
tmux emitting those escapes at all. Measured with a pane writing OSC 12: 3.6a
relays it, 3.7c relays it, 3.7c with the override emits zero cursor-colour
escapes. Trade: no application, and not tmux's own `cursor-colour` /
`prompt-cursor-colour` options either, can theme the cursor any more.

This supersedes the appendix's "only app-side, or nothing" conclusion: there is
a mux-side lever after all, and it is one line. It also makes the `crush` fish
wrapper's exit scrub (`printf '\e]112\a\e]111\a'`) redundant.

**crush, revisited.** The pin's original trigger ("drop it when #3734 closes")
was based on a stale issue: #3734 is still open but was last touched
2026-09-12, before the fix shipped. The fix is commit `066f4444d086`
("openaicompat: bump fantasy to fix regression around reasoning-only turns"),
first released in **v0.94.2** (2026-09-14), and the two issues naming the exact
error (#3794, #3689) were closed as completed the same day.

That fix does **not** cover this path. Reproduced on 0.95.0 with
`~/src/crush-cancel-repro` (`./probe.py --live`): a turn cancelled while the
model is still thinking is persisted with only reasoning, and
`preparePrompt`'s contentless-assistant guard exempts it
(`internal/agent/agent.go:1599`, the trailing
`&& m.ReasoningContent().String() == ""`), so the OpenAI-compatible converter
sends `{"role":"assistant","content":null,...}` and the gateway 400s every
later request in the session. 0.65.3 dropped the same turn. Whether it fires is
decided **per model**, not per provider: `deepseek-v4.1-flash` goes over
`/v1/chat/completions` (hit), `minimax-m2.7` over `/v1/messages` (dropped) --
which is why the upstream fix looked good from the anthropic side.

So `crush95` is now **0.95.0 built from source with that clause removed**
(`flake/patches/crush-0.95.0-reasoning-only.patch`), not the prebuilt tarball.
`subPackages = [ "." ]` keeps the tree's `internal/ui/logo/example` from
installing a colliding `bin/example`, and `doCheck = false` keeps a switch from
paying for a Go test run. Verified: `./probe.py --live` and `./probe.py --all`
both clean, and `go test ./internal/agent/... ./internal/message/...` passes.
Drop the patch when upstream lands it; the defect write-up, the fix rationale
and a draft upstream report are in `~/src/crush-cancel-repro` (`BUGS.md`,
`FIX.md`, `upstream-comment.md`).

Still open and **not** fixed by the patch: cancel does not stop work a tool has
handed off to the background manager (60s auto-background), and "busy" is
released only when the run returns, so a stuck run leaves the session wedged
and later prompts queued. Both are long-standing (same in 0.65.3) and are
issues, not regressions.

Immediate gotcha after the switch: a stale **distro** tmux server
(`/usr/bin/tmux` 3.4) was already sitting on the default socket, and the nix
3.7c client cannot attach to it (detached commands work, the attach handshake
makes the client exit, and WezTerm's `window_close_confirmation = "NeverPrompt"`
turns that into a window that vanishes on open). Same trap as the earlier
entry-point note, other direction: the absolute path in `default_prog` fixes
which *client* runs and cannot touch an already-running *server*. Cure is
`tmux kill-server`, after which the next window starts a matching server.
Ctrl+Shift+Z stays the escape hatch because it passes explicit args and never
touches `default_prog`.

## Changes made 2026-09-20 (WezTerm software rendering)

WezTerm defaults to a GPU front end, and on this machine the GPU path
composites badly (torn/ghosted cells, dropped redraws). Software rendering
moves compositing to the CPU, which is slower per frame but consistent.

| file | change | why |
|---|---|---|
| `wsl2/wezterm.lua` (+ `C:\Users\Rytter\.wezterm.lua`) | `config.front_end = "Software"` | `front_end` takes `"OpenGL"` (default), `"WebGpu"` or `"Software"`; the first two go through the Windows GPU driver, which is where the artefacts come from |

Cost: higher CPU use, and it is the path to check first if scrolling starts
feeling heavy — reverting is one line, then re-copy to Windows.

## Changes made 2026-09-25 (overnight-run context limits on the agent box)

Crush's auto-summarization triggers on the *declared* context window, and the
declared window is not the usable one: `opencode-go/deepseek-v4.1-flash`
advertises 1,000,000 tokens in the catalogue while the gateway starts rejecting
the session at about 660,000. A threshold derived from the declaration therefore
never fires before the wall, and the run dies with the whole session in context.
Two patches, applied to both builds:

| patch | change | why |
|---|---|---|
| `crush-0.95.0-context-ceiling.patch` | compaction triggers on an absolute `safeContextCeiling = 500_000` instead of on a fraction of the declared window, keeping a proportional reserve for small windows, a floor of one maximum-length reply, and a clamp at half the window | the declaration is not usable, and the fixed 20k buffer the >200k branch used is nothing next to a million; 500k leaves about 160k of margin before the wall, roughly two turns at the output cap below |
| `crush-0.95.0-truncate-fallback.patch` | a failed `Summarize` truncates the session (a marker message becomes the new context root) instead of returning the error and ending the turn | summarization is attempted exactly when the session is at its largest, so its failure must not be what kills the run, and eviction cannot fail the way a model call can |

Both live in `flake/patches/` and are mirrored into `iacthing/pkgs/patches/`,
which is what the box builds. The reply length is capped through the model
*slot* (`--max-tokens 65536` in the box's `crushrc`, `max_tokens` in
`crush.json`), not through `model add` or a `providers.<id>.models` entry:
re-registering a model id replaces the catalogue entry wholesale and drops its
`can_reason` and attachment flags.

Verified: the patched tree compiles (`nix build .#crush` in iacthing) and the
patches apply in order to pristine 0.95.0. Not yet verified: both behaviours at
runtime. The ceiling needs a session that reaches 500k, and the fallback needs a
summarization that fails; `~/src/crush-cancel-repro` is where a harness for that
kind of repro already lives.

## Changes made 2026-09-17/18 (crush × tmux × cursor colour, superseded above)

| file | change | why |
|---|---|---|
| `flake/modules/home/opencode.nix` | `programs.fish.functions.crush` wrapper: `command crush $argv` then `printf '\e]112\a\e]111\a'` | crush sets terminal cursor colour (`OSC 12`) and background (`OSC 11`) and only releases the cursor colour when its last rendered frame still had a themed cursor, so kills and dialog-exits leave it set; tmux remembers it per pane and replays it whenever that pane is active |
| `flake/modules/home/common.nix` | `set -g prompt-cursor-colour '#d5c4a1'` | works around the tmux 3.6–3.6b leak above; harmless on ≥3.7 |
| `flake/modules/home/common.nix` | root-table overrides for `C-h/C-j/C-k/C-l` and `S-Left/S-Right`: navigate when the pane's foreground command is a shell, forward the key otherwise | vim-tmux-navigator's guard enumerates vim-like apps, so crush never received them; crush wants `C-j`/`C-k` in its editor, `C-l` for the model picker, shift+arrows in its permission dialog |
| `wsl2/wezterm.lua` (+ copy at `C:\Users\Rytter\.wezterm.lua`) | `default_prog = { "/bin/bash", "-lc", "exec /home/rytter/.nix-profile/bin/tmux new-session -A -s main" }` | absolute path so the server is the nix tmux rather than the distro's 3.4, and a login shell so the server's PATH (which `run-shell`/plugins inherit) includes the nix profile |

Revert any of it with `git checkout -- <file>`; for the WezTerm change, re-copy
`wsl2/wezterm.lua` to Windows afterwards, then `tmux kill-server` and open a new
window. Nothing here is committed.

Not in the repo: the upstream bug report draft with the repro and evidence
(`OSC 12`/`112`, the tmux per-pane measurements, the bubbletea guard) lives at
`/tmp/crush-terminal-state-issue.md` and is worth filing.

## Loose ends

- `force_reverse_video_cursor = true` in `.wezterm.lua` does **not** fix the
  cursor complaint: WezTerm's docs say escape sequences take precedence over it
  (since build `20220319-142410-0fcdea07`), so it only overrides the colour
  scheme's cursor, never `OSC 12`. Ruled out 2026-09-18.
- The cursor leak is not agent-specific: opencode's binary emits `OSC 12`
  (`]12;#…`) and a reset too, so it is "cursor-theming TUI inside a mux that
  relays `OSC 12`". tmux relays it; Zellij drops it. The mux, not the agent,
  decides whether the colour can strand. (tmux 3.7c's own
  `prompt-cursor-colour` default is `none`, verified against the store builds.)
- Key namespace collision is a policy decision, not a bug: crush ships no keymap
  config, so either the tmux namespace yields (`vim-tmux-navigator`,
  `sensible`) or crush keeps losing those keys.
- The theming itself (crush owning its pane's background and cursor while it
  runs) is by design; only the release path is defective.

## Appendix: cursor colour — why it behaves differently from the background

Backgrounds never bleed across panes; cursor colours do. Same escape family
(`OSC 10/11/12`), same app, so the difference is structural, not a bug in the
app's background handling.

**The dividing line: which of the two has a per-cell override channel.**

- `OSC 10/11` (fg/bg) set *default cell colours*, and every cell can carry its
  own colours. A multiplexer owns the cells, so it can re-express the value in
  its own model — it never has to pass it to the terminal.
- `OSC 12` (cursor) is device state: the terminal draws the cursor, no cell "is"
  the cursor, and the only control is the terminal's single global setting.

Measured on a scratch tmux 3.6a, client on a pty:

| pane writes | relayed to the terminal | what tmux did instead |
|---|---|---|
| `OSC 11 ; #ff0000` | nothing | repainted cells with explicit `48;2;255;0;0` |
| `OSC 12 ; #ff00ff` | `^[]12;rgb:ff/00/ff^G` | nothing — relayed, global |

So tmux **translates** what it can own per pane and **relays** what it can't.
Consequences: per-pane background is real (simultaneous, scoped, terminal never
told); per-pane cursor colour is only emulated — tmux stores a value per pane
and turns the terminal's one dial when the active pane changes. It only speaks
when the value changes (`tty_force_cursor_colour`), and it has no rule to revert
an app-set colour when the process that set it exits, which is how a colour
survives a killed app, a pane switch, a tmux restart, and a new WezTerm window.

The missing invariant, if anyone patches tmux (files: `input.c` OSC handlers,
`screen.c` alternate-screen handling, `tty.c` `tty_force_cursor_colour`):
overrides set while on the alternate screen belong to that screen's process;
drop them when it leaves, re-assert the active pane's value on activation rather
than short-circuiting on the cache, and push `Cs=<cursor-colour>` instead of
trusting `Cr` (which several terminals don't implement — tmux#4759).

Who sidesteps this by construction:

- **Zellij draws the cursor as a cell it paints** (`render_fake_cursor` in
  `zellij-server/src/panes/terminal_pane.rs` sets `styles.background` on the
  character under the caret), and its VTE perform impl does not implement
  `set_background_color` / `set_foreground_color` / `set_cursor_style` at all —
  so apps inside cannot set these values; they're dropped, not translated or
  relayed. Nothing to leak, at the cost of no app cursor theming whatsoever.
- **Terminals that own their own splits** (WezTerm panes, kitty windows) scope
  correctly at *their* granularity, which is exactly why the bug only shows up
  when a multiplexer runs inside one of their panes: the terminal's scoping unit
  is its own pane, and tmux is opaque inside it.

To confirm empirically (tomorrow's project): run crush inside a scratch Zellij
session and check whether the cursor changes colour at all, whether anything
lingers after a `kill -9`, and how its default mode keys (Ctrl-p/n/t/s/o) collide
with crush's bindings — Zellij's are configurable (`keybinds`, `unbind`), unlike
crush's.

Harness: the pty probes used for the measurements above live in `/tmp`
(`tmux_osc_probe.py`, `tmux_bg_probe.py`, `nvim_probe.py`) — throwaway, but worth
copying in if more terminal-state forensics happen.
