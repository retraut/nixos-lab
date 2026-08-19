{ config, pkgs, lib, labUserName, ... }:

let
  # OpenAI's official Linux ChatGPT/Codex app is distributed as a Debian
  # package. NixOS is not an officially supported target, so run the package
  # in an FHS environment while keeping the installation declarative.
  chatgptUnwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-official";
    version = "26.810.52044";
    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
      hash = "sha256-cIoVobt24rt/DjduUUU5H6J3rTpkBXwdMlN73CobTm4=";
    };
    nativeBuildInputs = [ pkgs.libarchive ];
    dontUnpack = true;

    installPhase = ''
      mkdir -p "$out"
      deb_dir=$(mktemp -d)
      bsdtar -xf "$src" -C "$deb_dir"
      bsdtar -xf "$deb_dir/data.tar.xz" -C "$out"
    '';
  };

  chatgptRun = pkgs.writeShellScript "chatgpt-run" ''
    cd ${chatgptUnwrapped}/usr/lib/chatgpt
    exec ${chatgptUnwrapped}/usr/lib/chatgpt/ChatGPT --force-device-scale-factor=1.5 "$@"
  '';

  # Debian/FHS compatibility libraries for the official ChatGPT binary.
  # Keep these separate from the actual desktop application list below.
  chatgptRuntimeDeps = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    mesa
    nspr
    nss
    pango
    systemd
    xdg-utils
    zlib
  ];

  chatgptApp = pkgs.buildFHSEnv {
    name = "chatgpt";
    targetPkgs = _pkgs: chatgptRuntimeDeps;
    runScript = chatgptRun;
    extraInstallCommands = ''
      mkdir -p $out/share/applications $out/share/pixmaps
      cp ${chatgptUnwrapped}/usr/share/applications/chatgpt.desktop $out/share/applications/
      cp ${chatgptUnwrapped}/usr/share/pixmaps/chatgpt.png $out/share/pixmaps/
    '';
  };

  chromiumScaled = pkgs.symlinkJoin {
    name = "chromium-scaled";
    paths = [ pkgs.chromium ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/chromium" \
        --add-flags "--force-device-scale-factor=1.5"
    '';
  };

  desktopPackages = with pkgs; [
    chatgptApp
    chromiumScaled
    quickshell
    gtk3
    ghostty
    slack
    bitwarden-desktop
    curl
    eza
    gnome-calendar
    gnome-online-accounts
    screenfetch
    hyprsunset
    hypridle
    hyprlock
    nautilus
    jq
    python3
    libnotify
    wl-clipboard
    cliphist
    fuzzel
    brightnessctl
    bluez
    blueman
    networkmanagerapplet
    pavucontrol
    qrencode
    grim
    slurp
    swaybg
    hyprland-per-window-layout
  ];

  userServicePath = lib.makeBinPath (with pkgs; [
    bash
    coreutils
    findutils
    gnugrep
    jq
    procps
    quickshell
    swaybg
    hypridle
    hyprlock
    hyprland
    hyprland-per-window-layout
    wl-clipboard
    cliphist
    libnotify
  ]);
  userServiceEnvironment =
    "PATH=/home/${labUserName}/.local/bin:/etc/profiles/per-user/${labUserName}/bin:/run/current-system/sw/bin:${userServicePath}";
in
{
  # The compositor/session is ours. Quickshell is the only Omarchy-adjacent
  # Local runtime piece; no Omarchy CLI or Arch-specific shell runtime
  # is imported into NixOS.
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "hyprland-uwsm";

  security.polkit.enable = true;
  security.rtkit.enable = true;

  services.gnome.gnome-online-accounts.enable = true;
  services.upower.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  environment.systemPackages = desktopPackages;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit labUserName; };

    users.${labUserName} = {
      home.stateVersion = "26.05";

      xdg.userDirs = {
        enable = true;
        createDirectories = true;
      };

      # Desktop applications live in the system package set above. Keep only
      # user-scoped tools here so the same packages are not declared twice.
      home.packages = [ pkgs.codex ];

      programs.bash = {
        enable = true;
        shellAliases = {
          ls = "eza -lh --group-directories-first --icons=auto";
          lsa = "ls -a";
          ll = "eza -la";
          exa = "eza";
          lt = "eza --tree --level=2 --long --icons --git";
        };
      };

      programs.ghostty = {
        enable = true;
        settings = {
          # Super+W closes the active Ghostty surface through Hyprland. Keep
          # that action immediate; Chromium gets its own Ctrl+W tab binding.
          "confirm-close-surface" = false;
        };
      };

      home.sessionVariables = {
        XDG_CURRENT_DESKTOP = "Hyprland";
        XDG_SESSION_DESKTOP = "Hyprland";
        XDG_SESSION_TYPE = "wayland";
        QT_QPA_PLATFORM = "wayland;xcb";
        GDK_BACKEND = "wayland,x11,*";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
      };

      home.file = {
        ".local/share/applications/bitwarden.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Categories=Utility
            Comment=Secure and free password manager for all of your devices
            Exec=bitwarden --force-device-scale-factor=1.5 %U
            Icon=bitwarden
            MimeType=x-scheme-handler/bitwarden
            Name=Bitwarden
            Type=Application
            Version=1.5
          '';
        };
        ".config/autostart/bitwarden.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Bitwarden
            Comment=Declarative scaled Bitwarden autostart
            Exec=bitwarden --force-device-scale-factor=1.5 --autostart
            StartupNotify=false
            Terminal=false
          '';
        };
        ".local/share/applications/x-com.desktop".text = ''
          [Desktop Entry]
          Name=X
          Comment=X.com web app
          Exec=chromium --app=https://x.com
          Icon=x-logo
          Terminal=false
          Type=Application
          Categories=Network;WebBrowser;
          StartupNotify=true
        '';
        ".local/share/icons/hicolor/scalable/apps/x-logo.svg".source = ./assets/icons/x-logo.svg;
        ".config/hypr/hyprland.lua".source = ./hyprland.lua;
        ".config/hypr/hypridle.conf".source = ./hypridle.conf;
        ".config/quickshell/shell.qml".source = ./quickshell/shell.qml;
        ".config/quickshell/app-launcher.qml".source = ./quickshell/app-launcher.qml;
        ".config/quickshell/control-center.qml".source = ./quickshell/control-center.qml;
        ".config/quickshell/control-panel.qml".source = ./quickshell/control-panel.qml;
        ".config/quickshell/agents.qml".source = ./quickshell/agents.qml;
        ".config/quickshell/calendar.qml".source = ./quickshell/calendar.qml;
        ".config/quickshell/battery-panel.qml".source = ./quickshell/battery-panel.qml;
        ".config/quickshell/weather.qml".source = ./quickshell/weather.qml;
        ".config/quickshell/menu.qml".source = ./quickshell/menu.qml;
        ".config/quickshell/plugins".source = ./quickshell/plugins;
        ".config/quickshell/assets/agents/codex.svg".source = ./assets/icons/codex.svg;
        ".local/bin/nixos-shell" = {
          source = ./scripts/nixos-shell;
          executable = true;
        };
        ".local/bin/nixos-launcher" = {
          source = ./scripts/nixos-launcher;
          executable = true;
        };
        ".local/bin/nixos-control-center" = {
          source = ./scripts/nixos-control-center;
          executable = true;
        };
        ".local/bin/nixos-agents" = {
          source = ./scripts/nixos-agents;
          executable = true;
        };
        ".local/bin/nixos-calendar" = {
          source = ./scripts/nixos-calendar;
          executable = true;
        };
        ".local/bin/nixos-battery" = {
          source = ./scripts/nixos-battery;
          executable = true;
        };
        ".local/bin/nixos-weather" = {
          source = ./scripts/nixos-weather;
          executable = true;
        };
        ".local/bin/nixos-window-layout" = {
          source = ./scripts/nixos-window-layout;
          executable = true;
        };
        ".local/bin/nixos-system-stats" = {
          source = ./scripts/nixos-system-stats;
          executable = true;
        };
        ".local/bin/nixos-control-state" = {
          source = ./scripts/nixos-control-state;
          executable = true;
        };
        ".local/bin/nixos-control-action" = {
          source = ./scripts/nixos-control-action;
          executable = true;
        };
        ".local/bin/nixos-wifi-qr" = {
          source = ./scripts/nixos-wifi-qr;
          executable = true;
        };
        ".local/bin/nixos-agent-usage" = {
          source = ./scripts/nixos-agent-usage;
          executable = true;
        };
        ".local/bin/nixos-menu" = {
          source = ./scripts/nixos-menu;
          executable = true;
        };
        ".local/bin/nixos-background" = {
          source = ./scripts/nixos-background;
          executable = true;
        };
        ".local/bin/nixos-volume" = {
          source = ./scripts/nixos-volume;
          executable = true;
        };
        ".local/bin/nixos-brightness" = {
          source = ./scripts/nixos-brightness;
          executable = true;
        };
        ".local/bin/nixos-lock" = {
          source = ./scripts/nixos-lock;
          executable = true;
        };
        ".local/bin/nixos-clipboard" = {
          source = ./scripts/nixos-clipboard;
          executable = true;
        };
        ".local/bin/nixos-emoji" = {
          source = ./scripts/nixos-emoji;
          executable = true;
        };
        ".local/bin/nixos-capture" = {
          source = ./scripts/nixos-capture;
          executable = true;
        };
        ".local/share/nixos-shell/emojis.txt".source = ./data/emojis.txt;
      };

      # Long-running desktop helpers are tied to the graphical session and
      # automatically recover if one of them crashes.
      systemd.user.services = {
        nixos-shell = {
          Unit = {
            Description = "NixOS Quattro shell";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "%h/.local/bin/nixos-shell";
            Restart = "on-failure";
            RestartSec = 1;
            Environment = [ userServiceEnvironment ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        nixos-background = {
          Unit = {
            Description = "NixOS desktop background";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "%h/.local/bin/nixos-background";
            Restart = "on-failure";
            RestartSec = 1;
            Environment = [ userServiceEnvironment ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        nixos-window-layout = {
          Unit = {
            Description = "Per-window keyboard layouts";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "%h/.local/bin/nixos-window-layout";
            Restart = "on-failure";
            RestartSec = 1;
            Environment = [ userServiceEnvironment ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        nixos-hypridle = {
          Unit = {
            Description = "Hyprland idle and lock manager";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.hypridle}/bin/hypridle -c %h/.config/hypr/hypridle.conf";
            Restart = "on-failure";
            RestartSec = 1;
            Environment = [ userServiceEnvironment ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        nixos-cliphist-text = {
          Unit = {
            Description = "Clipboard history for text";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist store";
            Restart = "always";
            RestartSec = 1;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        nixos-cliphist-image = {
          Unit = {
            Description = "Clipboard history for images";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type image --watch ${pkgs.cliphist}/bin/cliphist store";
            Restart = "always";
            RestartSec = 1;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      };

      # Hyprland is configured as a native Lua file, matching the modern
      # Omarchy/Quattro direction, while all local behavior stays in our repo.
      wayland.windowManager.hyprland.enable = false;
    };
  };
}
