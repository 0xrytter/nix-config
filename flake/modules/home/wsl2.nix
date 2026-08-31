{ config, lib, pkgs, ... }:
{
  imports = [
    ./common.nix
    ./neovim.nix
  ];

  # ── WSL2 / Ubuntu adjustments ────────────────────────────────────────────────
  # No X11/Wayland here: drop the GUI bits that common.nix pulls in.
  programs.alacritty.enable = lib.mkForce false;
  programs.chromium.enable = lib.mkForce false;
  xdg.mimeApps.enable = lib.mkForce false;
  gtk.enable = lib.mkForce false;

  # Standalone home-manager on Ubuntu has no /run/current-system; resolve `gh`
  # from the user profile PATH instead.
  programs.git.settings."credential \"https://github.com\"".helper =
    lib.mkForce [ "" "!/usr/bin/env gh auth git-credential" ];
  programs.git.settings."credential \"https://gist.github.com\"".helper =
    lib.mkForce [ "" "!/usr/bin/env gh auth git-credential" ];

  # `rebuild.sh` is NixOS-only; point the fish helpers at the WSL2 switch script.
  programs.fish.functions.nr = lib.mkForce ''
    set -l root (fd -H -t f '^\.nix-config$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
    bash -c "cd $root && bash wsl2/switch.sh"
  '';
  programs.fish.functions.nu = lib.mkForce ''
    set -l root (fd -H -t f '^\.nix-config$' ~ --max-results 1 2>/dev/null | xargs -I{} dirname {})
    bash -c "cd $root && nix flake update --flake ./flake && bash wsl2/switch.sh"
  '';

  # Nerd fonts + fontconfig so Windows Terminal / VS Code can pick them up.
  fonts.fontconfig.enable = true;

  # Ubuntu's nix install only puts the nix bin dirs on PATH for bash login
  # shells(/etc/profile.d/nix.sh). When fish is the shell (WSL login or a tmux
  # default-shell pane) that never runs, so nix-installed tools like zoxide/nvim
  # become "not found". Ensure the nix user + default profile bins are always on
  # PATH inside fish. conf.d runs before config.fish, i.e. before hm-session-vars.
  xdg.configFile."fish/conf.d/10-nix-path.fish".text = ''
    set -l nix_link "$HOME/.nix-profile"
    if test -e "$nix_link/bin"
      if type -q fish_add_path
        fish_add_path --prepend --move "$nix_link/bin" "/nix/var/nix/profiles/default/bin"
      else
        set -gx PATH "$nix_link/bin" "/nix/var/nix/profiles/default/bin" $PATH
      end
    end
  '';

  home.packages = with pkgs; [
    git
    gh
    lazygit
    lazydocker
    docker-compose
    nerd-fonts.jetbrains-mono
  ];
}