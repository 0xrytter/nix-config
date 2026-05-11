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

### 5. Agent sandbox Docker images

Both `claude` and `pi` run inside Docker sandboxes — filesystem access is restricted to the current project directory only.

Images auto-build on first run, but building upfront avoids the delay:

```
# Claude Code sandbox
mkdir -p /tmp/claude-sandbox-build
cp $(readlink -f ~/.config/claude-sandbox/Dockerfile) /tmp/claude-sandbox-build/Dockerfile
docker build -t claude-sandbox /tmp/claude-sandbox-build/

# Pi sandbox (Docker-in-Docker)
mkdir -p /tmp/pi-sandbox-build
cp $(readlink -f ~/.config/pi-sandbox/Dockerfile) /tmp/pi-sandbox-build/Dockerfile
docker build -t pi-sandbox /tmp/pi-sandbox-build/
```

To bypass the sandbox and run the raw binary (e.g. for debugging):

```
command claude
command pi
```

To rebuild after a Dockerfile change:

```
docker rmi claude-sandbox && docker build -t claude-sandbox /tmp/claude-sandbox-build/
docker rmi pi-sandbox && docker build -t pi-sandbox /tmp/pi-sandbox-build/
```
