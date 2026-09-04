{ labUserName, ... }:

let
  # A physical Apple/Magic Keyboard exposes Command as Super/Meta to Linux.
  # This profile is intentionally separate from the PC Alt=Command profile.
  appleKeymap = ''
    keymap:
      # Keep physical Ctrl+C as SIGINT in terminals. Apple Command becomes
      # Super here and uses each terminal's clipboard shortcuts instead.
      - name: "Apple keyboard shortcuts in terminals"
        device:
          only: ["Apple", "Magic Keyboard"]
        application:
          only: [/ghostty|com\.mitchellh\.ghostty|com\.openai\.codex|codex|org\.retraut\.|nixos-rebuild|nnn-preview|alacritty|kitty|wezterm|terminal|org\.gnome\.Console|org\.gnome\.Terminal|org\.gnome\.Ptyxis|konsole|tilix|terminator|xterm|urxvt|st/]
        remap:
          Super-C: Ctrl-Shift-C
          Super-V: Ctrl-Shift-V
          Super-T: Ctrl-Shift-T
          Super-W: Ctrl-Shift-W
          Super-N: Ctrl-Shift-N
          Super-Q: Alt-F4
          Super-K: Ctrl-Shift-K

      # Command shortcuts for ordinary applications, including Slack,
      # Bitwarden, Thunderbird, the Codex app and file managers.
      - name: "Apple keyboard shortcuts in GUI apps"
        device:
          only: ["Apple", "Magic Keyboard"]
        application:
          not:
            - /ghostty|com\.mitchellh\.ghostty|com\.openai\.codex|codex|org\.retraut\.|nixos-rebuild|nnn-preview|alacritty|kitty|wezterm|terminal|org\.gnome\.Console|org\.gnome\.Terminal|org\.gnome\.Ptyxis|konsole|tilix|terminator|xterm|urxvt|st/
            - /^(chromium|chromium-browser|google-chrome|google-chrome-stable|brave-browser|microsoft-edge|firefox|vivaldi|opera)(\.|$)/
        remap:
          Super-C: Ctrl-C
          Super-V: Ctrl-V
          Super-X: Ctrl-X
          Super-A: Ctrl-A
          Super-Z: Ctrl-Z
          Super-Shift-Z: Ctrl-Shift-Z
          Super-S: Ctrl-S
          Super-F: Ctrl-F
          Super-L: Ctrl-L
          Super-R: Ctrl-R
          Super-P: Ctrl-P
          Super-T: Ctrl-T
          Super-W: Ctrl-W
          Super-N: Ctrl-N
          Super-Q: Ctrl-Q
          Super-comma: Ctrl-comma

      - name: "Apple keyboard shortcuts in browsers"
        device:
          only: ["Apple", "Magic Keyboard"]
        application:
          only: [/^(chromium|chromium-browser|google-chrome|google-chrome-stable|brave-browser|microsoft-edge|firefox|vivaldi|opera)(\.|$)/]
        remap:
          Super-C: Ctrl-C
          Super-V: Ctrl-V
          Super-X: Ctrl-X
          Super-A: Ctrl-A
          Super-Z: Ctrl-Z
          Super-Shift-Z: Ctrl-Shift-Z
          Super-S: Ctrl-S
          Super-F: Ctrl-F
          Super-P: Ctrl-P
          Super-Q: Ctrl-Q
          Super-comma: Ctrl-comma
          Super-R: Ctrl-R
          Super-Shift-R: Ctrl-Shift-R
          Super-T: Ctrl-T
          Super-W: Ctrl-W
          Super-N: Ctrl-N
          Super-L: Ctrl-L
          Super-1: Ctrl-1
          Super-2: Ctrl-2
          Super-3: Ctrl-3
          Super-4: Ctrl-4
          Super-5: Ctrl-5
          Super-6: Ctrl-6
          Super-7: Ctrl-7
          Super-8: Ctrl-8
          Super-9: Ctrl-9
          Super-0: Ctrl-0
          Super-Leftbrace: Alt-Left
          Super-Rightbrace: Alt-Right
          Super-Shift-Leftbrace: Ctrl-PageUp
          Super-Shift-Rightbrace: Ctrl-PageDown

      - name: "Apple keyboard shortcuts in Slack"
        device:
          only: ["Apple", "Magic Keyboard"]
        application:
          only: [/^(slack|Slack)(\.|$)/]
        remap:
          Super-K: Ctrl-K
          Super-1: Ctrl-1
          Super-2: Ctrl-2
          Super-3: Ctrl-3
          Super-4: Ctrl-4
          Super-5: Ctrl-5
          Super-6: Ctrl-6
          Super-7: Ctrl-7
          Super-8: Ctrl-8
          Super-9: Ctrl-9
          Super-0: Ctrl-0
  '';
in
{
  home-manager.users.${labUserName}.xdg.configFile."xremap/mac-keyboard.yml".text = appleKeymap;
}
