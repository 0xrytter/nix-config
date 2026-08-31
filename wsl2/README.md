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
    ├── tmux
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
tmux
Neovim
direnv / nix-direnv
prompt
CLI utilities
dotfiles
Nix configuration
```

After this step, the temporary Git shell is no longer important.

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

## 9. Install JetBrainsMono Nerd Font on Windows

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

## 10. Install WezTerm on Windows

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

## 11. WezTerm configuration

Use the following `.wezterm.lua`:

```lua
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- tmux owns windows/panes/tabs
config.enable_tab_bar = false

-- tmux survives terminal closure, so don't ask before closing
config.window_close_confirmation = "NeverPrompt"

-- Go directly into Ubuntu WSL
config.default_domain = "WSL:Ubuntu-24.04"

-- Start/attach persistent tmux session
local wsl_domains = wezterm.default_wsl_domains()

for _, domain in ipairs(wsl_domains) do
  if domain.name == "WSL:Ubuntu-24.04" then
    domain.default_prog = {
      "tmux",
      "new-session",
      "-A",
      "-s",
      "main",
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

-- Ctrl+Space must arrive at tmux as NUL / C-Space
config.keys = {
  {
    key = "Space",
    mods = "CTRL",
    action = wezterm.action.SendString("\x00"),
  },
}

-- Start maximized
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

return config
```

### Notes

WezTerm's own tab bar is disabled because tmux owns sessions, windows, and panes.

The terminal automatically runs:

```text
tmux new-session -A -s main
```

This means:

```text
main exists     -> attach
main missing    -> create
```

Closing WezTerm does not kill the tmux session.

Opening WezTerm again should attach to the existing `main` session.

`Ctrl+Space` is explicitly mapped to NUL because tmux uses it as the configured prefix and Windows terminal input otherwise may not transmit it correctly.

The maximize callback can cause a small visible startup/resize animation on Windows. This is cosmetic. If it becomes too annoying, remove the `gui-startup` callback and launch WezTerm from a Windows shortcut configured to run maximized instead.

---

## 12. Verify the Linux environment

Inside WSL/WezTerm:

```bash
nix --version
tmux -V
nvim --version
docker --version
systemctl is-active docker
```

Verify important tools are coming from Nix rather than Ubuntu where expected:

```bash
which tmux
which nvim
```

For example:

```bash
readlink -f "$(which tmux)"
```

should typically resolve somewhere under:

```text
/nix/store/...
```

---

## 13. Localhost networking

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

## 14. Optional: mirrored WSL networking

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

## 15. Useful WSL commands

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

## 16. Project workflow

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

## 17. Ownership split

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
tmux
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

## 18. Fresh-machine checklist

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
12. Run ./wsl2/docker-setup.sh
13. Install JetBrainsMono Nerd Font on Windows
14. Install WezTerm on Windows
15. Copy .wezterm.lua to %USERPROFILE%
16. Open WezTerm
17. Done
```

After that, normal development becomes:

```text
clone project
-> cd project
-> direnv allow
-> work
```

The workstation itself stays minimal and disposable. The reproducible development environment lives in Nix and the project flakes.
