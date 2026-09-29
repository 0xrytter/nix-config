# WSL2 finish steps

Four one-time steps to finish the WSL2 setup after pulling/rebuilding:

## 1. Make fish the login shell

Rebuilds home-manager, registers fish in `/etc/shells` and sets it as the
login shell (asks for sudo the first time only):

```
bash wsl2/switch.sh
```

Then exit/restart the distro so herdr's server is recreated with a clean
environment:

```
herdr server stop
exit
# from Windows PowerShell:  wsl --shutdown
```

Reopening WezTerm now boots straight into herdr, with fish as the default shell
inside its panes.

## 2. Deploy the WezTerm theme

`wsl2/wezterm.lua` is the WezTerm config used on the Windows side. It boots
straight into herdr and carries the Catppuccin Mocha palette by name, so the
terminal matches the stylix-themed terminals on the NixOS hosts.

- Copy `wsl2/wezterm.lua` from this repo to the Windows WezTerm config
  directory (`%USERPROFILE%\.wezterm.lua`, or wherever `WEZTERM_CONFIG_FILE`
  points).
- Restart WezTerm (close all its windows/`exit`ing the session) for the new
  colors to apply.

Note: the fish/herdr nix config takes effect after `home-manager switch`
(`bash wsl2/switch.sh`) — new herdr panes get the new shell/PATH; existing
panes keep their old environment until their shell restarts.

## 3. Put this machine on the tailnet

The iacthing boxes answer for their applications on the tunnel only, so without
this the fleet's Grafana and the agent box's API are unreachable from here.

```
bash wsl2/tailscale-setup.sh
```

The script links and starts the daemon, joins the tailnet - printing a URL to open
in Windows if the machine is not authorised yet - and hands the node to your user
so nothing afterwards needs sudo. The client comes from
`flake/modules/home/wsl2.nix`; the daemon is a system service, which is why it is a
linked systemd unit rather than anything home-manager could own on Ubuntu. Add
`--accept-dns` if you want the fleet's host names to resolve as well; details are
in step 9 of `wsl2/README.md`.

Windows stays off the tunnel either way — a browser there still needs an SSH
forward for the fleet's UI, documented in the iacthing repository's `ACCESS.md`.

## 4. Unlock the vault

Claude Code is the default harness and routes through Charm Hyper, but the key is
a secret the profile will not hold and no plaintext copy of it is kept. It lives
encrypted in the `secrets` repository, and the single age anchor that opens it is
stored only in the password manager.

Put that anchor on the clipboard from the password manager and run:

```bash
unlock
```

It takes only the `AGE-SECRET-KEY-1...` line, verifies the derived public key,
installs it at `$XDG_RUNTIME_DIR/sops/age/keys.txt` (mode 600, tmpfs), and loads
the ssh key into the agent. One paste per session - tmpfs does not survive a
reboot. Until it runs, `cclaude` refuses to start and `sec`/`secfile` report
*"anchor not unlocked"*; `command claude` runs the plain binary if the
first-party API is ever wanted instead. Details are in section 7 of
`wsl2/README.md` ("Agent credentials").
