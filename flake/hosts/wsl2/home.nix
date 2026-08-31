{ config, lib, ... }:
{
  home.username = "rytter";
  home.homeDirectory = "/home/rytter";
  home.stateVersion = "24.05";

  imports = [
    ../../modules/home/wsl2.nix
  ];

  programs.git.settings.user = {
    name = "rytter";
    email = "rytter.jakob@gmail.com";
  };

  programs.nixvim.extraConfigLua = ''
    for _, mode in ipairs({ 'n', 'x', 'o' }) do
      vim.keymap.set(mode, '<Left>',  'h')
      vim.keymap.set(mode, '<Right>', 'l')
      vim.keymap.set(mode, '<Down>',  'j')
      vim.keymap.set(mode, '<Up>',    'k')
    end
  '';

  programs.tmux.extraConfig = ''
    set -g @tmux-gruvbox-right-status-y "#(python3 ~/.config/tmux/ai-status.py headset 0) "

    set -g status 2
    set -g status-interval 5
    set -g status-format[1] "#[align=left]#(bash ~/.config/tmux/ai-dispatch.sh #{pane_current_command} #{pane_pid})"

    bind-key p run-shell 'printf "%s" "#{pane_current_path}" | clip.exe' \; display-message "Copied cwd: #{pane_current_path}"
  '';

  programs.fish.functions.dt = ''
    set -l root (fd -H -t f '^\.devtoolsthing$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
    $root/.venv/bin/python $root/tools.py $argv
  '';

  programs.fish.functions.cdm = ''
    cd (fd -H -t f ".$argv[1]" ~ --max-results 1 | xargs dirname)
  '';

  programs.fish.functions.ocgo1 = ''
    set -lx OPENCODE_CONFIG ${config.xdg.configHome}/opencode/profiles/go-workspace-1.json
    opencode $argv
  '';

  programs.fish.functions.ocgo2 = ''
    set -lx OPENCODE_CONFIG ${config.xdg.configHome}/opencode/profiles/go-workspace-2.json
    opencode $argv
  '';

  xdg.configFile."opencode/profiles/go-workspace-1.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = "opencode-go/qwen3.8-flash";
    provider.opencode-go.options.apiKey = "{file:${config.xdg.configHome}/opencode/secrets/go-workspace-1.key}";
  };

  xdg.configFile."opencode/profiles/go-workspace-2.json".text = builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = "opencode-go/qwen3.8-flash";
    provider.opencode-go.options.apiKey = "{file:${config.xdg.configHome}/opencode/secrets/go-workspace-2.key}";
  };

  home.activation.createOpencodeGoSecretDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/opencode/secrets
    $DRY_RUN_CMD chmod 700 ${config.xdg.configHome}/opencode/secrets
  '';
}