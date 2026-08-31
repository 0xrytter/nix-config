# nix-config

NixOS + home-manager configuration for T480, DIY-Desktop, patrick-desktop,
and a home-manager-only profile for Ubuntu on WSL2.

## Scripts (quick reference)

| Command | What it does |
| --- | --- |
| `bash rebuild.sh` | Rebuild the **NixOS system** (config + home-manager for that host) |
| `bash update.sh` | `nix flake update` then rebuild the NixOS system |
| `bash home.sh` | Rebuild **home-manager only** (auto-detects profile, or pass one: `home.sh wsl2`) |
| `bash home.sh --list` | List available home-manager profiles |
| `bash wsl2/bootstrap.sh` | First-time setup on a fresh Ubuntu WSL2 distro (install nix + home-manager) |
| `bash wsl2/switch.sh` | Rebuild home-manager for WSL2 |
| `bash wsl2/docker-setup.sh` | Install Docker Engine and run it as a daemon |
| `bash wsl2/docker-restart.sh` | Restart the Docker daemon |

NixOS machines: `rebuild.sh` compiles both the system and the home-manager
portion in one go. Standalone home-manager profiles are exposed for every host
(`wsl2`, `T480`, `DIY-Desktop`, `patrick-desktop`), so `home.sh` can apply a
home config without a full system rebuild.

## WSL2 (Ubuntu)

Standalone home-manager profile — no NixOS, no graphical UI. You get fish,
neovim, lazygit, lazydocker, opencode, tmux, nerd fonts and the usual dotfiles.

### 1. On a fresh Ubuntu WSL2 distro

```
git clone <this repo> && cd nix-config
bash wsl2/bootstrap.sh   # installs nix + home-manager and switch --flake ./flake#wsl2
```

Then set fish as your shell and restart the distro (WSL):

```
chsh -s $(which fish)
exit    # then `wsl --shutdown` from Windows PowerShell to enable systemd
```

### 2. Docker as a daemon

```
bash wsl2/docker-setup.sh    # installs Docker Engine, enables systemd, auto-starts dockerd
bash wsl2/docker-restart.sh  # restart the daemon any time
```

`docker-setup.sh` enables systemd in `/etc/wsl.conf` and enables the `docker`
service, so the daemon auto-starts on boot.

### 3. Rebuild when you change the config

```
bash wsl2/switch.sh
```

## First-time setup after deploy

Steps that are not managed by Nix and must be done manually on a fresh machine.

### 1. SSH keys

Copy or generate SSH keys into `~/.ssh/` and set permissions:

```
chmod 600 ~/.ssh/id_*
ssh-add
```

### 2. GitHub CLI

```
gh auth login
```

### 3. Claude Code

```
claude /login
```

### 4. Pi (OpenCode Go)

```
pi /login
```

Log in with OpenCode Go credentials to get access to Kimi and other models via the subscription.

Both `claude` and `pi` run directly on the host. They are installed by Nix/Home Manager; there is no Docker sandbox wrapper.
