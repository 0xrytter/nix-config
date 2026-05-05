{ pkgs, ... }: {
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''
      ################
      ### MONITORS ###
      ################
      monitor=,preferred,auto,auto

      ###################
      ### MY PROGRAMS ###
      ###################
      $terminal = alacritty
      $fileManager = nautilus
      $menu = wofi --show drun

      #################
      ### AUTOSTART ###
      #################
      exec-once = swww init
      exec-once = swww img ~/Wallpapers/gruvbox-mountain-village.png
      exec-once = nm-applet --indicator
      exec-once = waybar

      #############################
      ### ENVIRONMENT VARIABLES ###
      #############################
      env = XCURSOR_SIZE,24
      env = HYPRCURSOR_SIZE,24

      #####################
      ### LOOK AND FEEL ###
      #####################
      general {
          gaps_in = 5
          gaps_out = 20
          border_size = 2
          col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
          col.inactive_border = rgba(595959aa)
          resize_on_border = true
          allow_tearing = false
          layout = master
      }

      master {
          new_status = master
          mfact = 0.6
          orientation = left
      }

      decoration {
          rounding = 10
          active_opacity = 1.0
          inactive_opacity = 1.0
          shadow {
              enabled = true
              range = 4
              render_power = 3
              color = rgba(1a1a1aee)
          }
          blur {
              enabled = true
              size = 3
              passes = 1
              vibrancy = 0.1696
          }
      }

      animations {
          enabled = false
          bezier = myBezier, 0.05, 0.9, 0.1, 1.05
          animation = windows, 1, 7, myBezier
          animation = windowsOut, 1, 7, default, popin 80%
          animation = border, 1, 10, default
          animation = borderangle, 1, 8, default
          animation = fade, 1, 7, default
          animation = workspaces, 1, 6, default
      }

      dwindle {
          pseudotile = true
          preserve_split = true
      }

      misc {
          force_default_wallpaper = -1
          disable_hyprland_logo = false
      }

      #############
      ### INPUT ###
      #############
      input {
          kb_layout = dk
          kb_variant =
          kb_model =
          kb_options =
          kb_rules =
          repeat_delay = 300
          repeat_rate = 50
          follow_mouse = 1
          sensitivity = 0
          touchpad {
              natural_scroll = false
          }
      }

      gestures {
          workspace_swipe = false
      }

      ###################
      ### KEYBINDINGS ###
      ###################
      $mainMod = SUPER

      bind = $mainMod, Return, layoutmsg, swapwithmaster auto
      bind = $mainMod, M, layoutmsg, focusmaster auto
      bind = $mainMod SHIFT, N, layoutmsg, addmaster
      bind = $mainMod SHIFT, R, layoutmsg, removemaster
      bind = $mainMod, O, exec, rofi -show drun -show-icons
      bind = $mainMod, S, exec, grim -g "$(slurp)" | wl-copy
      bind = $mainMod, Q, exec, $terminal
      bind = $mainMod, C, killactive,
      bind = $mainMod, E, exec, $fileManager
      bind = $mainMod, V, togglefloating,
      bind = $mainMod, R, exec, $menu
      bind = $mainMod, P, pseudo,
      bind = $mainMod, J, togglesplit,

      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1

      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      bindel = ,XF86MonBrightnessUp, exec, brightnessctl s 10%+
      bindel = ,XF86MonBrightnessDown, exec, brightnessctl s 10%-

      ##############################
      ### WINDOWS AND WORKSPACES ###
      ##############################
      windowrulev2 = suppressevent maximize, class:.*
    '';
  };
}
