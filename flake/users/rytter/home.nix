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

  programs.fish.functions.dt = ''
    set -l root (fd -H -t f '^\.devtoolsthing$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
    $root/.venv/bin/python $root/tools.py $argv
  '';

  programs.fish.functions.cdm = ''
    cd (fd -H -t f ".$argv[1]" ~ --max-results 1 | xargs dirname)
  '';

  home.stateVersion = "24.05";
}
