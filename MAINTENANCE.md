# Maintenance

## Open problem: pins age silently

`nixpkgs` is pinned at `ed67bc86e84e` (2026-05-06). As of 2026-09-18 that pin is
four and a half months old, and nothing in this repo notices or reports that.

Versions actually in play today:

| component | in use | notes |
|---|---|---|
| nixpkgs pin | 2026-05-06 rev `ed67bc86e84e` | 4.5 months old |
| tmux (nix) | 3.6a | nixpkgs-unstable now has 3.7c |
| tmux (distro) | 3.4 | Ubuntu's `/usr/bin/tmux`, still on PATH |
| crush | 0.65.3 | pins bubbletea v2.0.6 |
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
   tmux display-message -p '#{version}'        # server version
   tmux run-shell 'command -v tmux; tmux -V'   # what plugins actually call
   tmux show -gv status-style                  # gruvbox applied?
   tmux list-keys | grep -c run-shell          # plugin binds present?
   crush --version; fish --version; nvim --version
   ```
4. **Track the non-nix components explicitly** — WezTerm is a Windows install
   (`C:\Users\Rytter\.wezterm.lua`, canonical copy in `wsl2/wezterm.lua`), bumped
   by hand and re-synced.
5. **Keep the version table above current** whenever a bump lands.

## Changes made 2026-09-18 (Zellij swap, Catppuccin, tmux/pi removal)

tmux is out and Zellij is in, on the WSL side only. The tmux work above is
superseded by the swap — the cursor-colour leak cannot occur under Zellij (it
does not implement `set_background_color` / `set_foreground_color` /
`set_cursor_style` at all, so an app's `OSC 10/11/12` is dropped rather than
relayed), and the key collisions are Zellij's own config surface now.

| file | change | why |
|---|---|---|
| `flake/modules/home/wsl2.nix` | `zellij` in `home.packages`; `xdg.configFile."zellij/config.kdl"` with `theme "catppuccin-mocha"`, `session_serialization`, `serialize_pane_viewport`, `scrollback_lines_to_serialize` | Zellij ships catppuccin itself, and serialization is its built-in resurrect/continuum equivalent — no plugin manager needed |
| `wsl2/wezterm.lua` (+ Windows copy) | `default_prog` now execs `zellij`; `config.colors` switched from gruvbox to Catppuccin Mocha (values from `base16-schemes/share/themes/catppuccin-mocha.yaml`, same base00/base05/ansi mapping as the gruvbox block) | stylix only themes the NixOS hosts and cannot reach a Windows-side WezTerm, so this file stays the source of truth for the terminal palette |
| `flake/modules/home/neovim.nix` | `colorschemes.gruvbox` → `colorschemes.catppuccin` | nvim ships its own colourscheme (stylix's neovim target is disabled in `common.nix`), so it needs the switch explicitly |
| `flake/modules/nixos/stylix.nix` | base16 scheme → `catppuccin-mocha.yaml`, generated wallpaper canvas `#282828` → `#1e1e2e` | flips the NixOS hosts (all stylix-managed apps) to Catppuccin; WSL has no stylix, so this is desktop-only |
| `flake/modules/home/common.nix`, `flake/hosts/wsl2/home.nix`, `flake/users/rytter/home.nix`, `flake/flake.nix` | removed `programs.tmux`, the tmux plugins block, the `tmux-gruvbox` input and its `extraSpecialArgs`, the `tmr` abbreviation | tmux is replaced by Zellij; `/usr/bin/tmux` (distro 3.4) remains as an emergency fallback, and the old config is recoverable from git history |
| deleted | `flake/config/pi-gruvbox.json`, `flake/config/pi-extensions/`, `flake/config/tmux/ai-status.py`, `flake/config/tmux/ai-dispatch.sh`; `agents.pi` dropped from `home.packages` | pi is not used any more, and the tmux status-line scripts have nothing to render into |

Still gruvbox on the machines (needs a decision or an asset):
`gtk.iconTheme` (`oomox-gruvbox-dark` / `gruvbox-dark-icons-gtk` — `catppuccin-cursors`
and `catppuccin-papirus-folders` exist in nixpkgs), and
`flake/modules/home/hyprland.nix`'s `swww img ~/Wallpapers/gruvbox-mountain-village.png`.

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

- `force_reverse_video_cursor = true` in `.wezterm.lua` may make the terminal
  ignore programmatic cursor colours entirely — a one-line candidate fix for the
  cursor complaint; unverified against the installed build.
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
