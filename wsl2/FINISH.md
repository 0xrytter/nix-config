# WSL2 finish steps

Two one-time steps to finish the WSL2 setup after pulling/rebuilding:

## 1. Make fish the login shell

Rebuilds home-manager, registers fish in `/etc/shells` and sets it as the
login shell (asks for sudo the first time only):

```
bash wsl2/switch.sh
```

Then exit/restart the distro so WezTerm's tmux server is recreated with a
clean environment:

```
tmux kill-server
exit
# from Windows PowerShell:  wsl --shutdown
```

Reopening WezTerm now attaches to tmux with fish as the default shell.

## 2. Deploy the WezTerm theme

`wsl2/wezterm.lua` is the WezTerm config used on the Windows side. It now
carries the grouped-dark-medium (base16) palette so the terminal matches the
stylix-themed terminals on the NixOS hosts.

- Copy `wsl2/wezterm.lua` from this repo to the Windows WezTerm config
  directory (`%USERPROFILE%\.wezterm.lua`, or wherever `WEZTERM_CONFIG_FILE`
  points).
- Restart WezTerm (close all its windows/`exit`ing the session) for the new
  colors to apply.

Note: the fish/tmux nix config takes effect after `home-manager switch`
(`bash wsl2/switch.sh`) — new tmux panes get the new shell/PATH; existing
panes keep their old environment until their shell restarts.