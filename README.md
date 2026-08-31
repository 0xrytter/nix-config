# nix-config

NixOS + home-manager configuration for T480, DIY-Desktop, patrick-desktop,
and a home-manager-only profile for Ubuntu on WSL2.

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
