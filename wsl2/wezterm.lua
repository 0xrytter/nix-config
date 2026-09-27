local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Disable the native tab bar
config.enable_tab_bar = false

-- Disable prompts for closing
config.window_close_confirmation = "NeverPrompt"

-- Go directly into Ubuntu WSL
config.default_domain = "WSL:Ubuntu-24.04"

-- Boot herdr, the workspace manager the agents live in. Bare `herdr` launches or
-- attaches to the persistent default session, so this attaches to the
-- workspaces already there rather than starting a fresh one. Herdr's own config
-- is declared in flake/config/herdr.toml; see wsl2/HERDR.md for the whole setup.
--  * Via a login shell with an absolute path: WezTerm's WSL domain inherits the
--    distro PATH, which has no nix profile, so a bare name resolves to
--    /usr/bin and the login shell is what restores the profile. The panes herdr
--    spawns inherit that PATH, which is what makes nix-installed agents such as
--    codex resolvable inside them.
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
config.font_size = 15.0

-- Catppuccin Mocha, by name. WezTerm ships the upstream catppuccin/wezterm
-- port as a built-in scheme (origin_url https://github.com/catppuccin/wezterm),
-- so the palette is the project's own, not a re-typed approximation. Mocha is
-- Catppuccin's dark flavour (latte is the light one, frappe/macchiato sit in
-- between). The hand-mapped base16 version that used to live here was wrong in
-- visible ways: ANSI black was the background (#1e1e2e), so dim black text
-- vanished, and bright black/yellow sat in the wrong slots.
-- stylix themes the NixOS hosts only and cannot reach a Windows-side WezTerm,
-- so this file stays the source of truth for the terminal palette.
config.color_scheme = "Catppuccin Mocha"

-- Block cursor, no blinking
config.default_cursor_style = "SteadyBlock"

-- Hide mouse while typing, same idea as Alacritty
config.hide_mouse_cursor_when_typing = true

-- Padding
config.window_padding = {
  left = 4,
  right = 4,
  top = 4,
  bottom = 4,
}

-- Keep normal Windows decorations
config.window_decorations = "TITLE | RESIZE"

-- Render in software. The GPU front ends (OpenGL/WebGPU) composite through the
-- Windows driver and produce artefacts here (torn/ghosted cells, dropped
-- redraws), so the CPU renderer is the stable path even though it costs more.
config.front_end = "Software"

config.keys = {
  -- Ctrl+Shift+Z: plain WSL shell in a new window, no herdr. Same domain and
  -- environment as the default window, minus the multiplexer — for comparing
  -- behaviour (scroll smoothness especially) with and without it.
  {
    key = "Z",
    mods = "CTRL|SHIFT",
    action = wezterm.action.SpawnCommandInNewWindow {
      domain = { DomainName = "WSL:Ubuntu-24.04" },
      args = { "/bin/bash", "-lc", "exec fish" },
    },
  },
}

-- Maximize on startup
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

return config
