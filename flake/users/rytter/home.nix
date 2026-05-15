{ pkgs, ... }: {
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/neovim.nix
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
  '';

  home.sessionVariables = {
    NIX_CONFIG_ROOT = "/home/rytter/Projects/nix-config";
    DEVTOOLS_ROOT   = "/home/rytter/Projects/thinglaunch/devtoolsthing";
  };

  programs.fish.functions.dt = ''
    $DEVTOOLS_ROOT/.venv/bin/python $DEVTOOLS_ROOT/tools.py $argv
  '';

  programs.fish.functions.cdm = ''
    cd (fd -H -t f ".$argv[1]" ~ --max-results 1 | xargs dirname)
  '';

  home.stateVersion = "24.05";
}
