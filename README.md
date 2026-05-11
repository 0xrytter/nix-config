# nix-config

NixOS + home-manager configuration for T480 and other machines.

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

### 5. Pi sandbox Docker image

The `pi` command runs inside a Docker-in-Docker sandbox — filesystem access is restricted to the current project directory with no access to the host system outside it.

Build the image once after first deploy. The Dockerfile is symlinked from the nix store, so docker can't read it directly — copy first:

```
mkdir -p /tmp/pi-sandbox-build
cp $(readlink -f ~/.config/pi-sandbox/Dockerfile) /tmp/pi-sandbox-build/Dockerfile
docker build -t pi-sandbox /tmp/pi-sandbox-build/
```

Or just run `pi` in any directory — the fish function will build automatically using the same workaround.

The image auto-builds if missing when you run `pi`, but building upfront avoids a delay on first use.

To rebuild after a Dockerfile change:

```
docker rmi pi-sandbox && docker build -t pi-sandbox ~/.config/pi-sandbox/
```
