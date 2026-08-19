{ config, pkgs, labUserName, ... }:

let
  colors = config.lib.stylix.colors.withHashtag;
  rawColors = config.lib.stylix.colors;

  quickshellTheme = ''
    import QtQuick

    // Generated from Stylix. Change the Base16 scheme in this repository.
    QtObject {
      readonly property color base00: "${colors.base00}"
      readonly property color base01: "${colors.base01}"
      readonly property color base02: "${colors.base02}"
      readonly property color base03: "${colors.base03}"
      readonly property color base04: "${colors.base04}"
      readonly property color base05: "${colors.base05}"
      readonly property color base06: "${colors.base06}"
      readonly property color base07: "${colors.base07}"
      readonly property color base08: "${colors.base08}"
      readonly property color base09: "${colors.base09}"
      readonly property color base0A: "${colors.base0A}"
      readonly property color base0B: "${colors.base0B}"
      readonly property color base0C: "${colors.base0C}"
      readonly property color base0D: "${colors.base0D}"
      readonly property color base0E: "${colors.base0E}"
      readonly property color base0F: "${colors.base0F}"

      readonly property color background: base00
      readonly property color muted: base04
      readonly property color foreground: base05
      readonly property color brightForeground: base07
      readonly property color accent: base0D
      readonly property color urgent: base08
      // Omarchy's current shell.toml uses subtle foreground-derived control
      // fills, rather than opaque Base16 surface blocks.
      readonly property color panel: Qt.rgba(base05.r, base05.g, base05.b, 0.04)
      readonly property color selected: Qt.rgba(base05.r, base05.g, base05.b, 0.08)
      readonly property color border: Qt.rgba(base05.r, base05.g, base05.b, 0.40)
      readonly property string fontFamily: "JetBrainsMono Nerd Font"
      // Single source of truth for bar and popup typography.
      readonly property int barFontSize: 20
      readonly property int barIconSize: 24
      readonly property int widgetFontSize: 30
      readonly property color scrim: Qt.rgba(base00.r, base00.g, base00.b, 0.50)
    }
  '';

  hyprlandTheme = ''
    return {
      background = "${rawColors.base00}",
      panel = "${rawColors.base01}",
      selected = "${rawColors.base02}",
      muted = "${rawColors.base03}",
      border = "${rawColors.base04}",
      foreground = "${rawColors.base05}",
      accent = "${rawColors.base0D}",
      urgent = "${rawColors.base08}",
      shadow = "0xee${rawColors.base00}",
    }
  '';

  hyprlockTheme = ''
    general {
        disable_loading_bar = true
        hide_cursor = true
        grace = 0
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
        outline_thickness = 3
        dots_size = 0.24
        dots_spacing = 0.32
        dots_center = true
        outer_color = rgb(${rawColors.base0D})
        inner_color = rgb(${rawColors.base00})
        font_color = rgb(${rawColors.base05})
        fade_on_empty = false
        placeholder_text = <span foreground="#${rawColors.base04}">Enter Password</span>
        hide_input = false
        check_color = rgb(${rawColors.base0A})
        fail_color = rgb(${rawColors.base08})
        fail_text = <span foreground="#${rawColors.base08}">$FAIL</span>
        capslock_color = rgb(${rawColors.base09})
        position = 0, -20
        halign = center
        valign = center
    }
  '';

  fuzzelTheme = ''
    [main]
    font=JetBrainsMono Nerd Font:size=15
    terminal=ghostty -e
    prompt=❯  
    width=64
    lines=12
    horizontal-pad=18
    vertical-pad=12
    inner-pad=8

    [colors]
    background=${rawColors.base00}f5
    text=${rawColors.base05}ff
    prompt=${rawColors.base0D}ff
    placeholder=${rawColors.base03}ff
    input=${rawColors.base05}ff
    match=${rawColors.base0A}ff
    selection=${rawColors.base02}ff
    selection-text=${rawColors.base07}ff
    selection-match=${rawColors.base0D}ff
    border=${rawColors.base04}ff

    [border]
    width=2
    radius=0
  '';
in
{
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = ./themes/tokyo-night.yaml;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
    };

    cursor = {
      package = pkgs.vanilla-dmz;
      name = "DMZ-Black";
      size = 24;
    };

    # Hyprland is authored as native Lua here, so its tokens are generated
    # below from the same Stylix palette.
  };

  home-manager.users.${labUserName} = {
    stylix.targets.ghostty.enable = true;

    home.file = {
      ".config/quickshell/Theme.qml".text = quickshellTheme;
      ".config/hypr/theme.lua".text = hyprlandTheme;
      ".config/hypr/hyprlock.conf".text = hyprlockTheme;
      ".config/fuzzel/fuzzel.ini".text = fuzzelTheme;
      ".local/share/nixos-theme/tokyo-night-quattro.jpg".source = ./assets/backgrounds/tokyo-night-quattro.jpg;
    };
  };
}
