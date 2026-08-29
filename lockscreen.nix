{ config, labUserName, ... }:

let
  rawColors = config.lib.stylix.colors;
in
{
  # Hyprlock is kept in its own module so lockscreen behavior can evolve
  # independently from the broader desktop theme.
  home-manager.users.${labUserName}.home.file.".config/hypr/hyprlock.conf".text = ''
    general {
        disable_loading_bar = true
        hide_cursor = true
        grace = 0
        success_timeout = 1000
        fail_timeout = 900
    }

    auth {
        fingerprint {
            enabled = true
            ready_message =
            present_message =
            retry_delay = 1000
        }
    }

    background {
        monitor =
        path = /home/${labUserName}/.local/share/nixos-theme/tokyo-night-quattro.jpg
        color = rgb(${rawColors.base00})
        blur_passes = 3
        blur_size = 8
        noise = 0.018
        contrast = 0.92
        brightness = 0.72
    }

    label {
        monitor =
        text = $TIME
        color = rgb(${rawColors.base05})
        font_family = JetBrainsMono Nerd Font
        font_size = 72
        position = 0, 170
        halign = center
        valign = center
    }

    label {
        monitor =
        text = cmd[update:60000] date +"%A, %d %B"
        color = rgb(${rawColors.base04})
        font_family = JetBrainsMono Nerd Font
        font_size = 22
        position = 0, 105
        halign = center
        valign = center
    }

    input-field {
        monitor =
        size = 420, 68
        fingerprint_size = 96, 96
        fingerprint_font_size = 64
        outline_thickness = 3
        rounding = 18
        dots_size = 0.24
        dots_spacing = 0.32
        dots_center = true
        outer_color = rgb(${rawColors.base0D})
        inner_color = rgb(${rawColors.base00})
        font_color = rgb(${rawColors.base04})
        font_family = JetBrainsMono Nerd Font
        fade_on_empty = false
        fingerprint_text = 󰈷
        placeholder_text =
        hide_input = false
        check_color = rgb(${rawColors.base0B})
        success_color = rgb(${rawColors.base0B})
        fail_color = rgb(${rawColors.base08})
        success_text = Success
        fail_text = Failed
        capslock_color = rgb(${rawColors.base09})
        position = 0, 0
        halign = center
        valign = center
    }
  '';
}
