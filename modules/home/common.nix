{ pkgs, pkgs-unstable, ... }: {
  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = false;
    };
  };

  programs.fish.enable = true;

  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  home.packages = with pkgs; [
    fd
    ripgrep
    gh
    lazygit
    lazydocker
    tmux
    neovim
  ];
}
