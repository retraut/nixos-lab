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
      readonly property int barIconSize: 20
      readonly property int barIconSlotWidth: 30
      readonly property int barIconSlotHeight: 30
      readonly property int widgetFontSize: 30
      // Shared geometry for desktop popup surfaces. Weather intentionally
      // stays wider because its hourly and weekly forecasts are horizontal.
      readonly property int popupWidth: 560
      readonly property int popupPadding: 20
      readonly property int popupTopMargin: 44
      readonly property int popupEdgeMargin: 12
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
      ".config/fuzzel/fuzzel.ini".text = fuzzelTheme;
      ".local/share/nixos-theme/tokyo-night-quattro.jpg".source = ./assets/backgrounds/tokyo-night-quattro.jpg;
    };
  };
}
