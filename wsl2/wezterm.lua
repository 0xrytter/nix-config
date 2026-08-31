local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Disable the native tab bar
config.enable_tab_bar = false

-- Disable prompts for closing
config.window_close_confirmation = "NeverPrompt"

-- Go directly into Ubuntu WSL
config.default_domain = "WSL:Ubuntu-24.04"

-- Start tmux exactly like your Alacritty setup
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

-- Same colors as your Alacritty config
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
}

-- Maximize on startup
wezterm.on("gui-startup", function(cmd)
  local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
  window:gui_window():maximize()
end)

return config