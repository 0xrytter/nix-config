# Windows + WSL2 + Ubuntu + Nix Development Workstation

This setup keeps Windows as the host OS while running the actual development environment inside WSL2.

The intended split is:

```text
Windows 11
├── Hardware / drivers
├── Wi-Fi / Bluetooth
├── VPN / corporate tooling
├── Browser / Rider / other GUI apps
├── WezTerm
└── JetBrainsMono Nerd Font

WSL2
└── Ubuntu 24.04 LTS
    ├── Nix
    ├── Home Manager
    ├── herdr
    ├── Neovim
    ├── direnv / nix-direnv
    ├── Docker Engine
    └── Project flakes
```

The guiding principle is:

> Ubuntu is the compatibility substrate. Nix is the development environment. Repositories own their own toolchains.

Project SDKs, compilers, runtimes, native dependencies, and other development tooling should live in each project's `flake.nix` rather than being installed globally.

---

## 1. Install WSL2 and Ubuntu 24.04

Open **PowerShell as Administrator** and run:

```powershell
wsl --install -d Ubuntu-24.04
```

Reboot Windows if requested.

After reboot, verify the installation:

```powershell
wsl -l -v
```

Expected result:

```text
NAME            STATE     VERSION
Ubuntu-24.04    Running   2
```

If Ubuntu is not running yet:

```powershell
wsl -d Ubuntu-24.04
```

On first launch, Ubuntu will ask for a Linux username and password.

---

## 2. Move to the Linux filesystem

If WSL was launched from PowerShell, it may inherit the Windows working directory and start somewhere like:

```text
/mnt/c/Windows/system32
```

Do not develop there.

Move to the Linux home directory:

```bash
cd
```

Verify:

```bash
pwd
```

Expected:

```text
/home/<username>
```

Create the source directory:

```bash
mkdir -p src
cd src
```

Keep repositories under paths such as:

```text
/home/<username>/src/project
```

Avoid:

```text
/mnt/c/Users/<username>/...
```

This is important for filesystem performance. Git operations, builds, deletes, caches, Nix operations, `node_modules`, and similar workloads should stay on the Linux filesystem.

---

## 3. Install the minimal Ubuntu prerequisites

Ubuntu only needs enough tooling to bootstrap Nix.

```bash
sudo apt update
sudo apt install -y curl
```

Avoid installing development SDKs or language toolchains through `apt`. Those belong in Nix/project flakes.

---

## 4. Install Nix

Install Nix using the upstream multi-user daemon installer:

```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

When the installer finishes, close the current shell:

```bash
exit
```

Open Ubuntu/WSL again.

Verify:

```bash
nix --version
```

---

## 5. Bootstrap Git temporarily through Nix

Do not create a manual Nix configuration file just to enable flakes.

Use the feature flags directly for the bootstrap shell:

```bash
nix --extra-experimental-features "nix-command flakes" shell nixpkgs#git
```

Verify:

```bash
git --version
```

This gives you Git temporarily through Nix without installing it globally through Ubuntu.

---

## 6. Clone the Nix configuration repository

From the Linux filesystem:

```bash
cd
mkdir -p src
cd src
git clone <YOUR-NIX-CONFIG-REPOSITORY>
cd <YOUR-NIX-CONFIG-REPOSITORY>
```

The repository should contain the scripts used to finish the machine setup.

---

## 7. Run the Nix/Home Manager bootstrap

Run (from the repository root):

```bash
./wsl2/bootstrap.sh
```

`wsl2/bootstrap.sh` is responsible for applying the Nix flake and Home Manager configuration.

It should configure the Linux user environment, including the things owned by Nix/Home Manager, such as:

```text
shell
Git
herdr
Neovim
direnv / nix-direnv
prompt
CLI utilities
dotfiles
Nix configuration
```

After this step, the temporary Git shell is no longer important.

### Agent credentials

The profile declares the harnesses but never their secrets, and nothing secret
is ever written into the Nix store. Credentials live encrypted in the `secrets`
repository (`~/src/secrets/secrets/personal.enc.yaml`) and are fetched at the
moment of use by two accessors declared in `flake/modules/home/secrets.nix`:

| Command | Returns |
| --- | --- |
| `sec <name>` | the value on stdout — for a consumer that wants an env var |
| `secfile <name>` | a tmpfs path, mode 0400 — for the few that need a path |

Both decrypt with the **age anchor**, which is not on disk. Put it on the
clipboard from the password manager and run `unlock`: it takes only the
`AGE-SECRET-KEY-1...` line, verifies the derived public key, and installs it at
`$XDG_RUNTIME_DIR/sops/age/keys.txt` (mode 600, tmpfs — gone at reboot, so one
paste per session). `unlock` then loads the ssh key into the agent. Until it
runs, `sec` and `secfile` refuse with *"anchor not unlocked"* rather than handing
a consumer an empty credential.

**Leave `~/.config/sops/age/keys.txt` absent.** It is the path `sops` falls back
to when `SOPS_AGE_KEY_FILE` is unset *or* points at a key that does not work, so
a copy there silently makes the paste optional and puts the master key back on
disk. With that path empty, the paste is what unlocks the environment.

Claude Code runs through **Charm Hyper** with the `cclaude` launcher, which
fetches its key with `sec hyper-api-key` at start. `claude` stays the stock
Anthropic binary, untouched, and `cclaude` is that same binary bootstrapped with
Charm Hyper as the API provider: `deepseek-v4.1-flash` is the default model,
`kimi-k3` and `glm-5.3-flash` fill the `sonnet` and `haiku` slots, and `/model`
shows all three in place of the built-in lineup (`hyperClaudeSettings` in
`flake/modules/home/wsl2.nix`, handed over with `--settings`). Gateway discovery
cannot do this for us - it keeps only model ids containing `claude` or
`anthropic`, and Hyper serves open-weight models. Without an anchor `cclaude`
refuses to start rather than quietly falling back to Anthropic.

`flake/config/agent-rules.md` is the agent system prompt, deployed to
`~/.claude/CLAUDE.md`. It tells the agents the same thing: never create a
plaintext secret, fetch with `sec`/`secfile`, and treat a locked anchor as the
user's step rather than something to work around.

---

## 8. Set up Docker

Run (from the repository root):

```bash
./wsl2/docker-setup.sh
```

`wsl2/docker-setup.sh` is responsible for setting up Docker Engine inside Ubuntu/WSL, including the required daemon/service configuration.

After it finishes, verify Docker:

```bash
systemctl is-active docker
```

Expected:

```text
active
```

Detailed check without opening the pager:

```bash
systemctl --no-pager status docker
```

Test the daemon:

```bash
docker run --rm hello-world
```

If needed, Docker can be restarted with:

```bash
sudo systemctl restart docker
```

### WSL systemd note

Docker Engine requires systemd.

If `docker.sh` enables systemd through `/etc/wsl.conf`, restart WSL from PowerShell afterward:

```powershell
wsl --shutdown
```

Then reopen Ubuntu/WSL.

---

## 9. Tailscale (reaching the fleet)

The iacthing boxes are tailnet-only. Their Grafana, Loki, VictoriaMetrics and the
agent box's API answer on the tunnel and nowhere else. SSH is the one exception,
open on every box, which is why the repository scripts work from anywhere while
the applications need this step.

The client is declared in `flake/modules/home/wsl2.nix`, so it arrives with the
profile. The daemon is a system service, because it creates a tun interface and
that needs root - and home-manager owns no system services on Ubuntu. The unit
file therefore lives in this repository, and one script does the rest:

```bash
bash wsl2/tailscale-setup.sh
```

It links and starts the daemon, joins the tailnet - printing a URL to open in
Windows if this machine is not authorised yet - and finally hands the node to your
user, so nothing afterwards needs sudo. It asks for the password once. Re-running
it is safe.

Add `--accept-dns` if you want the fleet's host names as well as its addresses:

```bash
bash wsl2/tailscale-setup.sh --accept-dns
```

Then check it:

```bash
tailscale status               # the three boxes should be listed
curl -s http://obs01:3000/api/health
crush -H tcp://agent01:7799
```

Every call the script makes to the client uses its full path, because `sudo`
resets `PATH` to a root-safe default and a client living in your home profile is
invisible to it: `sudo tailscale` finds nothing while plain `tailscale` works.
The operator flag is what removes that asymmetry afterwards.

### Host names, or addresses

Without `--accept-dns` the fleet's names do not resolve and the addresses have to
be used instead:

```bash
curl -s http://100.118.112.28:3000/api/health
```

With it, tailscale owns `/etc/resolv.conf` - it rewrites that file when the daemon
starts, which is what makes `agent01` resolve rather than only `100.76.233.93`.
WSL regenerates the file on every distro start, so if a restart ever leaves names
not resolving, `/etc/wsl.conf` settles the race:

```ini
[network]
generateResolvConf = false
```

An address is stable while a node exists; a re-provisioned box joins again and gets
a new one. The iacthing repository's `status.sh` prints the current address of
every host, which is the answer when a name cannot be trusted.

### Talking to the agent box

Once this machine is on the tailnet, `agent` is the client for the fleet's agent
box - the same patched 0.95.0 build the box runs, pointed at it over the tunnel:

```bash
cd ~/src/<repo>
agent                                            # the TUI
agent run "reply with the single word: ready"    # one shot, non-interactive
```

**Run it from the directory you want it to work in.** A crush client sends its own
working directory as the workspace path and the server resolves it *on the box*, so
the same path has to exist at both ends. The fleet mirrors `/home/rytter/src` on
agent01 for exactly that reason, which is why the habit is `cd ~/src/<repo>` first:
the agent then works in that same path on the box.

No API key is involved here on purpose: the credential stays on the box and the box
does the work, including every file it touches. And that cuts both ways - what it can
touch is what exists *under that mirrored path on the box*, so cloning a repository
here does not put it there.

Two things that look like something else when they go wrong:

- **Without the env var it runs locally.** `CRUSH_CLIENT_SERVER=1` (set inside the
  `agent` function) is the whole difference between driving the server and running
  the agent in this process; without it the TUI opens, answers, and reads *your*
  files, which is a very convincing thing to watch.
- **The client sends its environment with the request.** A credential exported in
  that shell travels to the box, so start it from a shell holding nothing you would
  not hand over.

One thing this does not do: Windows stays off the tunnel. This joins WSL only, so a
Windows browser still needs an SSH forward for the fleet's UI, and the commands for
those are in the iacthing repository's `ACCESS.md`.

---

## 10. Install JetBrainsMono Nerd Font on Windows

The terminal renderer runs on Windows, so the terminal font must be installed on Windows as well.

Install:

```text
JetBrainsMono Nerd Font
```

Download the Nerd Font archive, extract it, select the `.ttf` files, right-click, and choose:

```text
Install for all users
```

Windows will register the fonts in its normal system font collection.

This is one of the small pieces of workstation configuration that lives outside Nix/Home Manager because the Windows GUI is rendering the terminal.

---

## 11. Install WezTerm on Windows

Install WezTerm normally on Windows.

The WezTerm configuration file should live at:

```text
%USERPROFILE%\.wezterm.lua
```

For example:

```text
C:\Users\<windows-user>\.wezterm.lua
```

Keep the canonical `.wezterm.lua` in the Nix/dotfiles repository and copy it into the Windows user profile when setting up a new machine.

Example from PowerShell:

```powershell
Copy-Item `
  "<PATH-TO-NIX-CONFIG>\wezterm\.wezterm.lua" `
  "$env:USERPROFILE\.wezterm.lua"
```

Adjust the source path to match the repository layout.

A manual copy is also perfectly fine.

---

## 12. WezTerm configuration

This is the shape of `wsl2/wezterm.lua`; that file in the repo is the source of
truth, so copy it rather than retyping this.

```lua
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- herdr owns workspaces/tabs/panes
config.enable_tab_bar = false

-- herdr survives terminal closure, so don't ask before closing
config.window_close_confirmation = "NeverPrompt"

-- Go directly into Ubuntu WSL
config.default_domain = "WSL:Ubuntu-24.04"

-- Boot herdr. Absolute path inside a login shell: the WSL domain inherits the
-- distro PATH, which has no nix profile, and the login shell is what restores
-- it for herdr and for every pane it spawns.
local wsl_domains = wezterm.default_wsl_domains()

for _, domain in ipairs(wsl_domains) do
  if domain.name == "WSL:Ubuntu-24.04" then
    domain.default_prog = {
      "/bin/bash",
      "-lc",
      "exec /home/rytter/.nix-profile/bin/herdr",
    }
  end
end

config.wsl_domains = wsl_domains

-- Font
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 18.0

-- Colors
config.colors = {
  foreground = "#cdd6f4",
  background = "#1e1e2e",

  cursor_bg = "#f5e0dc",
  cursor_fg = "#1e1e2e",
  cursor_border = "#f5e0dc",

  ansi = {
    "#45475a",
    "#f38ba8",
    "#a6e3a1",
    "#f9e2af",
    "#89b4fa",
    "#f5c2e7",
    "#94e2d5",
    "#bac2de",
  },

  brights = {
    "#585b70",
    "#f38ba8",
    "#a6e3a1",
    "#f9e2af",
    "#89b4fa",
    "#f5c2e7",
    "#94e2d5",
    "#a6adc8",
  },

  indexed = {
    [16] = "#fab387",
    [17] = "#f5e0dc",
  },
}

-- Block cursor
config.default_cursor_style = "SteadyBlock"

-- Hide mouse while typing
config.hide_mouse_cursor_when_typing = true

-- Padding
config.window_padding = {
  left = 4,
  right = 4,
  top = 4,
  bottom = 4,
}

-- Normal Windows decorations
config.window_decorations = "TITLE | RESIZE"

-- Start maximized
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

return config
```

### Notes

WezTerm's own tab bar is disabled because herdr owns sessions, workspaces, tabs
and panes.

The terminal boots straight into:

```text
exec /home/rytter/.nix-profile/bin/herdr
```

A bare `herdr` (no `--session`) launches or attaches to the persistent default
session, so closing WezTerm leaves the session and its panes running, and opening
it again attaches to what is already there.

The maximize callback can cause a small visible startup/resize animation on Windows. This is cosmetic. If it becomes too annoying, remove the `gui-startup` callback and launch WezTerm from a Windows shortcut configured to run maximized instead.

---

## 13. Verify the Linux environment

Inside WSL/WezTerm:

```bash
nix --version
herdr --version
nvim --version
docker --version
systemctl is-active docker
```

Verify important tools are coming from Nix rather than Ubuntu where expected:

```bash
which herdr
which nvim
```

For example:

```bash
readlink -f "$(which herdr)"
```

should typically resolve somewhere under:

```text
/nix/store/...
```

---

## 14. Localhost networking

Servers running inside WSL should be reachable directly from the Windows host through `localhost`.

For example, inside WSL:

```bash
python -m http.server 8000
```

Then open from the Windows browser:

```text
http://localhost:8000
```

The same applies to normal development ports:

```text
http://localhost:3000
http://localhost:5000
http://localhost:8080
```

This allows the Linux environment to run the application while Windows runs the browser, Rider, API client, or other GUI tooling.

---

## 15. Optional: mirrored WSL networking

For simpler bidirectional localhost behavior and potentially better interaction with VPNs, create:

```text
%USERPROFILE%\.wslconfig
```

containing:

```ini
[wsl2]
networkingMode=mirrored
```

Apply it with:

```powershell
wsl --shutdown
```

Then reopen WSL.

This is optional. If the default networking already works for everything required, there is no need to add extra configuration.

---

## 16. Useful WSL commands

From PowerShell:

### Enter the default WSL distro

```powershell
wsl
```

### Explicitly enter Ubuntu

```powershell
wsl -d Ubuntu-24.04
```

### Show installed distros and WSL versions

```powershell
wsl -l -v
```

### Fully stop WSL

```powershell
wsl --shutdown
```

`wsl --shutdown` is useful after changing WSL-level configuration such as `/etc/wsl.conf` or `%USERPROFILE%\.wslconfig`.

---

## 17. Project workflow

Projects remain fully self-contained.

A typical repository looks like:

```text
project/
├── flake.nix
├── flake.lock
├── .envrc
└── src/
```

Clone:

```bash
cd ~/src
git clone <repository>
cd <repository>
```

Activate:

```bash
direnv allow
```

The project flake provides its own:

```text
SDKs
compilers
language runtimes
native libraries
build tools
project-specific CLIs
environment variables
development scripts
```

There should normally be no reason to install things such as `.NET`, Node, Rust, Go, Python, Java, GCC, or Clang globally on Ubuntu.

---

## 18. Ownership split

### Windows owns

```text
WSL2
Ubuntu installation
drivers
Wi-Fi / Bluetooth
displays
VPN / corporate tooling
browser
Rider / other GUI applications
WezTerm
JetBrainsMono Nerd Font
```

### Ubuntu owns

```text
WSL integration
systemd
users/groups
Docker daemon
any mandatory corporate Linux tooling
```

### Nix / Home Manager owns

```text
shell
Git
herdr
Neovim
direnv / nix-direnv
prompt
dotfiles
CLI utilities
developer user environment
```

### Project flakes own

```text
SDKs
compilers
language runtimes
native dependencies
build tools
project-specific tooling
```

---

## 19. Fresh-machine checklist

The complete setup is:

```text
1. Install WSL2 + Ubuntu 24.04
2. Reboot Windows if required
3. Create Ubuntu user
4. Move into the Linux home directory
5. sudo apt update
6. sudo apt install -y curl
7. Install Nix
8. Restart the WSL shell
9. Start a temporary Nix shell containing Git
10. Clone nix-config
11. Run ./wsl2/bootstrap.sh
12. Put the age anchor on the clipboard and run `unlock` (section 7, "Agent credentials")
13. Run ./wsl2/docker-setup.sh
14. Run ./wsl2/tailscale-setup.sh (it joins the tailnet and prints the URL to authorise)
15. Install JetBrainsMono Nerd Font on Windows
16. Install WezTerm on Windows
17. Copy .wezterm.lua to %USERPROFILE%
18. Open WezTerm
19. Done
```

After that, normal development becomes:

```text
clone project
-> cd project
-> direnv allow
-> work
```

The workstation itself stays minimal and disposable. The reproducible development environment lives in Nix and the project flakes.
