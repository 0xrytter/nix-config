{ pkgs, pkgs-unstable, ... }: {
  programs.git = {
    enable = true;
    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      pull.rebase = false;
    };
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      fish_vi_key_bindings

      if not pgrep ssh-agent > /dev/null
          eval (ssh-agent -c)
          ssh-add
      end
      if not set -q SSH_AUTH_SOCK
          eval (ssh-agent -c)
      end
    '';
  };

  programs.fzf.enable = true;
  programs.zoxide.enable = true;

  home.file.".ideavimrc".source = ../../config/ideavimrc;

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
