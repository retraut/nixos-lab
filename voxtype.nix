{ config, pkgs, lib, labUserName, ... }:

let
  voxtypeModel = "large-v3-turbo";
  voxtypeMaxDurationSecs = 300;
in
{
  # Keep Voxtype available to compositor keybindings and interactive use
  # without making it part of the general desktop package list.
  environment.systemPackages = [ pkgs.voxtype-vulkan ];

  home-manager.users.${labUserName} = {
    services.voxtype = {
      enable = true;
      package = pkgs.voxtype-vulkan;
      loadModels = [ voxtypeModel ];
      environment = {
        # The daemon launches voxtype-osd by name. Keep the Voxtype package
        # on PATH so the OSD frontend is discoverable from systemd too.
        PATH = lib.makeBinPath [
          pkgs.voxtype-vulkan
          # Voxtype runs post-process and output hooks through `sh -c`.
          # NixOS has no global /bin/sh, so keep a shell on the service PATH.
          pkgs.bash
          pkgs.coreutils
          pkgs.which
          pkgs.wl-clipboard
          pkgs.wtype
          pkgs.jq
          pkgs.hyprland
        ];
        VOXTYPE_VULKAN_DEVICE = "amd";
        # The user service can start before Hyprland imports its session
        # environment. Give wtype the active Wayland socket explicitly.
        WAYLAND_DISPLAY = "wayland-1";
        DISPLAY = ":0";
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
      };
      settings = {
        audio = {
          max_duration_secs = voxtypeMaxDurationSecs;
        };
        hotkey.enabled = false;
        whisper = {
          model = voxtypeModel;
          language = [ "uk" "en" ];
          translate = false;
        };
        output = {
          # Copy one normalized line and paste it as a single bracketed-paste
          # operation. Ghostty remaps this layout-independent shortcut to the
          # regular clipboard, so PRIMARY selection can never be pasted here.
          mode = "paste";
          paste_keys = "shift+insert";
          pre_type_delay_ms = 200;
          post_process = {
            command = "${pkgs.coreutils}/bin/tr '\\r\\n' '  '";
            timeout_ms = 5000;
          };
          auto_submit = false;
          notification = {
            on_recording_start = false;
            on_recording_stop = false;
            on_transcription = false;
          };
        };
        osd = {
          # The nixpkgs Voxtype package ships the launcher but not the
          # GTK4/Quickshell frontend binaries. Our Quickshell shell hosts
          # the state/audio HUD instead.
          enabled = false;
        };
      };
    };

    home.file = {
      ".config/quickshell/voxtype-model".text = "${voxtypeModel}\n";
      ".config/quickshell/voxtype-timeout".text = "${toString voxtypeMaxDurationSecs}\n";
    };
  };
}
