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

  programs.fish.shellAbbrs = {
    micon = "pactl set-card-profile bluez_card.00_22_BB_B9_F9_C0 headset-head-unit";
    micoff = "pactl set-card-profile bluez_card.00_22_BB_B9_F9_C0 a2dp-sink";
  };

  home.packages = with pkgs; [ pulseaudio ];

  home.stateVersion = "24.05";
}
