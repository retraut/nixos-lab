{ pkgs, labUserName, ... }:

let
  # xremap works before Hyprland and translates the physical Alt key into
  # the Ctrl shortcuts expected by Linux applications. This keeps the
  # macOS muscle memory while leaving physical Ctrl available for terminal
  # signals and readline.
  macKeymap = ''
    # macOS-style shortcuts for a PC keyboard:
    #   Alt  -> Command (Ctrl in Linux applications)
    #   Ctrl -> Ctrl (signals and terminal editing remain unchanged)
    #
    # The separate mac-keyboard-profile.nix handles physical Apple keyboards.
    keymap:
      # Global clipboard layer for the PC profile. xremap matches these names
      # against evdev keys, so the physical C/V keys work in both US and UA
      # layouts. Terminal applications get their own override immediately
      # below so Alt+C/V still copy/paste without changing Ctrl+C (SIGINT).
      - name: "PC global macOS clipboard"
        device:
          not: ["Apple", "Magic Keyboard"]
        application:
          not: [/ghostty|com\.mitchellh\.ghostty|com\.openai\.codex|codex|org\.retraut\.|nixos-rebuild|nnn-preview|alacritty|kitty|wezterm|terminal|org\.gnome\.Console|org\.gnome\.Terminal|org\.gnome\.Ptyxis|konsole|tilix|terminator|xterm|urxvt|st/]
        remap:
          Alt-C: Ctrl-C
          Alt-V: Ctrl-V

      # Terminal rules deliberately keep Ctrl+C as SIGINT. The Insert chords
      # are Ghostty's explicit clipboard actions and match the Super+V helper.
      - name: "PC macOS shortcuts in terminals"
        device:
          not: ["Apple", "Magic Keyboard"]
        application:
          only: [/ghostty|com\.mitchellh\.ghostty|com\.openai\.codex|codex|org\.retraut\.|nixos-rebuild|nnn-preview|alacritty|kitty|wezterm|terminal|org\.gnome\.Console|org\.gnome\.Terminal|org\.gnome\.Ptyxis|konsole|tilix|terminator|xterm|urxvt|st/]
        remap:
          Alt-C: Ctrl-Insert
          Alt-V: Shift-Insert
          Alt-T: Ctrl-Shift-T
          Alt-W: Ctrl-Shift-W
          Alt-N: Ctrl-Shift-N
          Alt-Q: Alt-F4
          Alt-K: Ctrl-Shift-K

      # Common Cmd shortcuts for every non-terminal application, including
      # Chromium, Slack, Nautilus, Bitwarden, Thunderbird and the Codex app.
      - name: "PC macOS shortcuts in GUI apps"
        device:
          not: ["Apple", "Magic Keyboard"]
        application:
          not:
            - /ghostty|com\.mitchellh\.ghostty|com\.openai\.codex|codex|org\.retraut\.|nixos-rebuild|nnn-preview|alacritty|kitty|wezterm|terminal|org\.gnome\.Console|org\.gnome\.Terminal|org\.gnome\.Ptyxis|konsole|tilix|terminator|xterm|urxvt|st/
            - /^(chromium|chromium-browser|google-chrome|google-chrome-stable|brave-browser|microsoft-edge|firefox|vivaldi|opera)(\.|$)/
            - /^(slack|Slack|com\.slack\.Slack)(\.|$)/
        remap:
          Alt-X: Ctrl-X
          Alt-A: Ctrl-A
          Alt-Z: Ctrl-Z
          Alt-Shift-Z: Ctrl-Shift-Z
          Alt-S: Ctrl-S
          Alt-L: Ctrl-L
          Alt-R: Ctrl-R
          Alt-P: Ctrl-P
          Alt-T: Ctrl-T
          Alt-W: Ctrl-W
          Alt-N: Ctrl-N
          Alt-Q: Ctrl-Q
          Alt-comma: Ctrl-comma

      # Browser-only Cmd shortcuts. This block repeats the common GUI rules
      # because browsers are excluded from the generic GUI block below.
      - name: "PC macOS shortcuts in browsers"
        device:
          not: ["Apple", "Magic Keyboard"]
        application:
          only: [/^(chromium|chromium-browser|google-chrome|google-chrome-stable|brave-browser|microsoft-edge|firefox|vivaldi|opera)(\.|$)/]
        remap:
          # Common Cmd shortcuts still apply inside browser text fields.
          Alt-X: Ctrl-X
          Alt-A: Ctrl-A
          Alt-Z: Ctrl-Z
          Alt-Shift-Z: Ctrl-Shift-Z
          Alt-S: Ctrl-S
          Alt-P: Ctrl-P
          Alt-Q: Ctrl-Q
          Alt-comma: Ctrl-comma

          # Chromium/macOS basics: refresh, tabs, windows and address bar.
          Alt-R: Ctrl-R
          Alt-Shift-R: Ctrl-Shift-R
          Alt-T: Ctrl-T
          Alt-W: Ctrl-W
          Alt-N: Ctrl-N
          Alt-L: Ctrl-L

          # Cmd+1…9 selects a tab; Cmd+0 resets browser zoom.
          Alt-1: Ctrl-1
          Alt-2: Ctrl-2
          Alt-3: Ctrl-3
          Alt-4: Ctrl-4
          Alt-5: Ctrl-5
          Alt-6: Ctrl-6
          Alt-7: Ctrl-7
          Alt-8: Ctrl-8
          Alt-9: Ctrl-9
          Alt-0: Ctrl-0

          # Cmd+[ / Cmd+] navigate history; Cmd+Shift+[ / ] switch tabs.
          Alt-Leftbrace: Alt-Left
          Alt-Rightbrace: Alt-Right
          Alt-Shift-Leftbrace: Ctrl-PageUp
          Alt-Shift-Rightbrace: Ctrl-PageDown

      # Slack follows the browser/Electron Cmd conventions, with its
      # workspace and quick-switcher shortcuts called out explicitly.
      - name: "PC macOS shortcuts in Slack"
        device:
          not: ["Apple", "Magic Keyboard"]
        application:
          only: [/^(slack|Slack|com\.slack\.Slack)(\.|$)/]
        remap:
          # Alt+C/V come from the global clipboard layer above.
          Alt-X: Ctrl-X
          Alt-A: Ctrl-A
          Alt-Z: Ctrl-Z
          Alt-Shift-Z: Ctrl-Shift-Z
          Alt-S: Ctrl-S
          Alt-L: Ctrl-L
          Alt-R: Ctrl-R
          Alt-P: Ctrl-P
          Alt-T: Ctrl-T
          Alt-W: Ctrl-W
          Alt-N: Ctrl-N
          Alt-Q: Ctrl-Q
          Alt-comma: Ctrl-comma
          Alt-K: Ctrl-K
          Alt-1: Ctrl-1
          Alt-2: Ctrl-2
          Alt-3: Ctrl-3
          Alt-4: Ctrl-4
          Alt-5: Ctrl-5
          Alt-6: Ctrl-6
          Alt-7: Ctrl-7
          Alt-8: Ctrl-8
          Alt-9: Ctrl-9
          Alt-0: Ctrl-0

  '';
in
{
  # xremap emits a virtual keyboard through uinput and needs access to the
  # input devices. Keep the permissions in the same module as its keymap.
  hardware.uinput.enable = true;
  users.users.${labUserName}.extraGroups = [ "input" "uinput" ];
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", TAG+="uaccess"
  '';

  home-manager.users.${labUserName} = {
    xdg.configFile."xremap/mac.yml".text = macKeymap;

    systemd.user.services.nixos-xremap = {
      Unit = {
        Description = "Mac-style keyboard semantics for the NixOS desktop";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.xremap.hyprland}/bin/xremap --watch=device,config %h/.config/xremap/mac.yml %h/.config/xremap/mac-keyboard.yml";
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
