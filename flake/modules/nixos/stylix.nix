{ pkgs, ... }: {
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";
    image = pkgs.runCommand "gruvbox-wallpaper.png" { buildInputs = [ pkgs.imagemagick ]; } ''
      magick -size 1920x1080 canvas:#282828 PNG:$out
    '';
    targets.gnome.enable = false;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sizes.terminal = 18;
    };
  };
}
