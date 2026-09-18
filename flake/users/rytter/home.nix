{ config, lib, pkgs, ... }: {
  imports = [
    ../../modules/home/common.nix
    ../../modules/home/neovim.nix
    ../../modules/home/opencode.nix
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

  programs.fish.functions.dt = ''
    set -l root (fd -H -t f '^\.devtoolsthing$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
    $root/.venv/bin/python $root/tools.py $argv
  '';

  programs.fish.functions.cdm = ''
    cd (fd -H -t f ".$argv[1]" ~ --max-results 1 | xargs dirname)
  '';

  # transitional: superseded by the generic `ocgo N` from modules/home/opencode.nix.
  # Remove once the new system is confirmed working.
  programs.fish.functions.ocgo1 = ''
    set -lx OPENCODE_CONFIG ${config.xdg.configHome}/opencode/profiles/go-workspace-1.json
    opencode $argv
  '';

  programs.fish.functions.ocgo2 = ''
    set -lx OPENCODE_CONFIG ${config.xdg.configHome}/opencode/profiles/go-workspace-2.json
    opencode $argv
  '';

  home.stateVersion = "24.05";
}
