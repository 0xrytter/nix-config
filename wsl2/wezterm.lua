local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Disable the native tab bar
config.enable_tab_bar = false

-- Disable prompts for closing
config.window_close_confirmation = "NeverPrompt"

-- Go directly into Ubuntu WSL
config.default_domain = "WSL:Ubuntu-24.04"

-- Boot Zellij instead of tmux.
--  * Via a login shell with an absolute path: WezTerm's WSL domain inherits the
--    distro PATH, which has no nix profile, so a bare name resolves to
--    /usr/bin and the login shell is what restores the profile.
--  * Zellij's config and package are declared in flake/modules/home/wsl2.nix.
--  * tmux stays installed and configured; to go back, swap this exec line for
--    "/home/rytter/.nix-profile/bin/tmux new-session -A -s main".
local wsl_domains = wezterm.default_wsl_domains()

for _, domain in ipairs(wsl_domains) do
  if domain.name == "WSL:Ubuntu-24.04" then
    domain.default_prog = {
      "/bin/bash",
      "-lc",
      "exec /home/rytter/.nix-profile/bin/zellij",
    }
  end
end

config.wsl_domains = wsl_domains

-- Font
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font_size = 15.0

-- Catppuccin Mocha, mapped the same way the gruvbox block was: base00
-- background, base05 text, base08/0B/0A/0D/0E/0C in ANSI slots 1-6, base03 and
-- base07 for bright black/white. Values taken from
-- base16-schemes/share/themes/catppuccin-mocha.yaml — stylix themes the NixOS
-- hosts only and cannot reach a Windows-side WezTerm, so this file stays the
-- source of truth for the terminal palette.
config.colors = {
  foreground = "#cdd6f4",
  background = "#1e1e2e",

  cursor_bg = "#cdd6f4",
  cursor_fg = "#1e1e2e",
  cursor_border = "#cdd6f4",

  ansi = {
    "#1e1e2e",
    "#f38ba8",
    "#a6e3a1",
    "#f9e2af",
    "#89b4fa",
    "#cba6f7",
    "#94e2d5",
    "#cdd6f4",
  },

  brights = {
    "#6c7086",
    "#f38ba8",
    "#a6e3a1",
    "#f9e2af",
    "#89b4fa",
    "#cba6f7",
    "#94e2d5",
    "#b4befe",
  },

  indexed = {
    [16] = "#fab387",
    [17] = "#f2cdcd",
  },
}

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

-- Ctrl+Space -> NUL, matching what tmux expects for C-Space
config.keys = {
  {
    key = "Space",
    mods = "CTRL",
    action = wezterm.action.SendString("\x00"),
  },
  -- Ctrl+Shift+Z: plain WSL shell in a new window, no Zellij. Same domain and
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