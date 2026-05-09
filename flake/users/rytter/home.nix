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

  home.stateVersion = "24.05";
}
