{ config, pkgs, lib, labUserName, ... }:

let
  nnn = pkgs.nnn.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ./packages/nnn-space-preview.patch ];
    postInstall = (old.postInstall or "") + ''
      # Keep nnn's generic package desktop entry out of the user profile;
      # the desktop profile below provides the Ghostty launcher instead.
      rm -f "$out/share/applications/nnn.desktop"
    '';
  });
  codex = pkgs.callPackage ./codex.nix { };
  commandCode = pkgs.callPackage ./packages/command-code.nix { };
  desktopDaemon = pkgs.rustPlatform.buildRustPackage {
    pname = "nixos-desktop-daemon";
    version = "0.1.0";
    src = ./packages/nixos-desktop-daemon;
    cargoLock.lockFile = ./packages/nixos-desktop-daemon/Cargo.lock;
    meta.mainProgram = "nixos-desktop-daemon";
  };
  previewDaemon = pkgs.rustPlatform.buildRustPackage {
    pname = "nnn-preview-daemon";
    version = "0.1.0";
    src = ./packages/nnn-preview-daemon;
    cargoLock.lockFile = ./packages/nnn-preview-daemon/Cargo.lock;
    meta.mainProgram = "nnn-preview-daemon";
  };

  # OpenAI's official Linux ChatGPT/Codex app is distributed as a Debian
  # package. NixOS is not an officially supported target, so run the package
  # in an FHS environment while keeping the installation declarative.
  chatgptUnwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "chatgpt-official";
    version = "26.818.61809";
    src = pkgs.fetchurl {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
      hash = "sha256-G7piptvS1Jl1xihQ2O3arWBdoZNVexlJgiJeVrGUGJE=";
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
    exec ${chatgptUnwrapped}/usr/lib/chatgpt/ChatGPT \
      --ozone-platform=wayland "$@"
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
    libglvnd
    libnotify
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libva
    mesa
    nspr
    nss
    pango
    systemd
    bubblewrap
    # Codex Security's MCP manifest launches its server via `node`.
    nodejs
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

  universalPasteHelper = pkgs.writeShellScriptBin "nixos-universal-paste" ''
    set -euo pipefail

    # App-aware paste for the physical Super+V binding.
    window_class="$(${lib.getExe' pkgs.hyprland "hyprctl"} activewindow -j 2>/dev/null \
      | ${lib.getExe pkgs.jq} -r '[(.class // ""), (.initialClass // "")] | join(" ")' \
      | ${lib.getExe' pkgs.coreutils "tr"} '[:upper:]' '[:lower:]')"

    send_shortcut() {
      mods="$1"
      key="$2"

      # Match Hyprland's layout-independent Super+V implementation exactly:
      # send a physical key down/up pair instead of a layout-dependent keysym.
      ${lib.getExe' pkgs.hyprland "hyprctl"} eval \
        "hl.dispatch(hl.dsp.send_key_state({ mods = \"$mods\", key = \"$key\", state = \"down\" }))" \
        >/dev/null
      ${lib.getExe' pkgs.coreutils "sleep"} 0.05
      ${lib.getExe' pkgs.hyprland "hyprctl"} eval \
        "hl.dispatch(hl.dsp.send_key_state({ mods = \"$mods\", key = \"$key\", state = \"up\" }))" \
        >/dev/null
    }

    case "$window_class" in
      # These apps are terminal-like even though they use their own Alt-Tab
      # class, so paste through the terminal path just like Ghostty.
      *ghostty*|*com.openai.codex*|*org.retraut.*|*nnn*|*alacritty*|*kitty*|*wezterm*|*terminal*)
        send_shortcut "SHIFT" "Insert"
        ;;
      *)
        send_shortcut "CTRL" "code:55"
        ;;
    esac
  '';

  chromiumScaled = pkgs.symlinkJoin {
    name = "chromium-scaled";
    paths = [ pkgs.chromium ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/chromium" \
        --add-flags "--force-device-scale-factor=1.0"
    '';
  };

  # Keep the display manager password-only, but give it a proper Tokyo Night
  # presentation. The background is copied into the immutable theme package
  # so the greeter does not depend on a user's home directory being mounted.
  sddmAstronaut = (pkgs.sddm-astronaut.override {
    embeddedTheme = "astronaut";
    themeConfig = {
      HeaderText = "";
      HeaderTextColor = "#a9b1d6";
      DateTextColor = "#7aa2f7";
      TimeTextColor = "#c0caf5";
      Background = "Backgrounds/tokyo-night-quattro.jpg";
      FormBackgroundColor = "#1a1b26";
      BackgroundColor = "#13141c";
      DimBackgroundColor = "#13141c";
      LoginFieldBackgroundColor = "#292e42";
      PasswordFieldBackgroundColor = "#292e42";
      LoginFieldTextColor = "#c0caf5";
      PasswordFieldTextColor = "#c0caf5";
      UserIconColor = "#7aa2f7";
      PasswordIconColor = "#7aa2f7";
      PlaceholderTextColor = "#565f89";
      WarningColor = "#f7768e";
      LoginButtonTextColor = "#1a1b26";
      LoginButtonBackgroundColor = "#7aa2f7";
      SystemButtonsIconsColor = "#a9b1d6";
      SessionButtonTextColor = "#a9b1d6";
      VirtualKeyboardButtonTextColor = "#a9b1d6";
      DropdownTextColor = "#c0caf5";
      DropdownSelectedBackgroundColor = "#292e42";
      DropdownBackgroundColor = "#1a1b26";
      HighlightTextColor = "#1a1b26";
      HighlightBackgroundColor = "#7aa2f7";
      HighlightBorderColor = "#7aa2f7";
      HoverUserIconColor = "#bb9af7";
      HoverPasswordIconColor = "#bb9af7";
      HoverSystemButtonsIconsColor = "#bb9af7";
      HoverSessionButtonTextColor = "#bb9af7";
      HoverVirtualKeyboardButtonTextColor = "#bb9af7";
      PartialBlur = "true";
      BlurMax = "12";
      Blur = "0.55";
      HaveFormBackground = "true";
      FormPosition = "center";
      VirtualKeyboardPosition = "center";
      HideVirtualKeyboard = "true";
      HideSystemButtons = "false";
      UseRealName = "true";
      ForceLastUser = "true";
      PasswordFocus = "true";
      HideCompletePassword = "true";
      AllowEmptyPassword = "false";
    };
  }).overrideAttrs (oldAttrs: {
    installPhase = oldAttrs.installPhase + ''
      chmod u+w $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/
      cp ${./assets/backgrounds/tokyo-night-quattro.jpg} \
        $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/tokyo-night-quattro.jpg
    '';
  });

  desktopPackages = with pkgs; [
    chatgptApp
    t3code
    chromiumScaled
    quickshell
    xremap.hyprland
    gtk3
    ghostty
    slack
    bitwarden-desktop
    curl
    lsof
    powertop
    gitMinimal
    eza
    gnome-keyring
    thunderbird
    fastfetch
    hyprsunset
    wlsunset
    hypridle
    hyprlock
    nautilus
    jq
    libnotify
    upower
    wl-clipboard
    wtype
    cliphist
    fuzzel
    brightnessctl
    bluez
    blueman
    python3
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
    dbus
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
    upower
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

  # Steam needs NixOS' module rather than only the package so its 32-bit
  # graphics stack and runtime integration are configured correctly.
  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # Current Steam builds occasionally ignore the environment variable
      # after their client re-exec. Pass the equivalent startup flag as well.
      extraArgs = "-forcedesktopscaling 1.5";
      extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "1.5";
    };
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "sddm-astronaut-theme";
    extraPackages = [
      pkgs.kdePackages.qtmultimedia
      pkgs.kdePackages.qtsvg
      pkgs.qt6Packages.qtvirtualkeyboard
    ];
    settings = {
      General.InputMethod = "qtvirtualkeyboard";
      Theme.Current = "sddm-astronaut-theme";
    };
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  security.polkit = {
    enable = true;
    enablePkexecWrapper = true;
  };
  security.rtkit.enable = true;

  services.gnome.gnome-keyring.enable = true;
  # Quick Look-style file preview for Nautilus (Spacebar).
  services.gnome.sushi.enable = true;
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

  programs.chromium = {
    enable = true;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb;https://clients2.google.com/service/update2/crx"
      "bgnkhhnnamicmpeenaelnjfhikgbkllg;https://clients2.google.com/service/update2/crx"
    ];
    extraOpts = {
      # Allow Slack's browser sign-in callback to launch the desktop client.
      # Without this, Chromium can block the slack:// redirect from Slack's
      # web origins even though the XDG scheme handler is registered.
      AutoLaunchProtocolsFromOrigins = [
        {
          protocol = "slack";
          # Slack SSO may hand off from an external identity provider.
          # Use the documented wildcard temporarily to cover that callback;
          # narrow this to the actual provider once the flow is confirmed.
          allowed_origins = [ "*" ];
        }
      ];
      # Slack's SSO flow may use a redirect/popup before handing off to the
      # desktop client's slack:// URL.
      PopupsAllowedForUrls = [
        "https://slack.com"
        "https://app.slack.com"
        "https://[*.]slack.com"
      ];
    };
  };

  environment.systemPackages = desktopPackages ++ [ sddmAstronaut ];

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

      # Keep links opened by Thunderbird and other applications in Chromium.
      # This also prevents the ChatGPT desktop app from becoming the default
      # XDG browser when its desktop entry is installed.
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "text/html" = [ "chromium-browser.desktop" ];
          "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
          "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
          "x-scheme-handler/slack" = [ "slack.desktop" ];
          "x-scheme-handler/bitwarden" = [ "bitwarden.desktop" ];
          "x-scheme-handler/codex" = [ "chatgpt.desktop" ];
        };
        associations.added = {
          "x-scheme-handler/slack" = [ "slack.desktop" ];
          "x-scheme-handler/bitwarden" = [ "bitwarden.desktop" ];
          "x-scheme-handler/codex" = [ "chatgpt.desktop" ];
        };
      };
      xdg.configFile."mimeapps.list".force = true;

      # Keep nnn user-scoped so its generic package desktop entry does not
      # become a second system application alongside our Ghostty launcher.
      home.packages = [ codex commandCode nnn previewDaemon pkgs.nodejs ];

      programs.bash = {
        enable = true;
        shellAliases = {
          ls = "eza -lh --group-directories-first --icons=auto";
          lsa = "ls -a";
          ll = "eza -la";
          exa = "eza";
          lt = "eza --tree --level=2 --long --icons --git";
          nnn = "NNN_FIFO=/run/user/1000/nnn-preview.fifo nnn";
          restore_my_init_nixos_configuration = "sudo nixos-rebuild switch --flake /etc/nixos#laptop";
        };
      };

      programs.ghostty = {
        enable = true;
        settings = {
          # Super+W closes the active Ghostty surface through Hyprland. Keep
          # that action immediate; Chromium gets its own Ctrl+W tab binding.
          "confirm-close-surface" = false;

          # VoxType and the universal paste helper deliberately use the
          # layout-independent Shift+Insert chord. Ghostty maps that chord to
          # PRIMARY selection by default, so point it at the regular clipboard
          # instead; otherwise selected text can replace the transcription.
          keybind = "shift+insert=paste_from_clipboard";
        };
      };

      home.sessionVariables = {
        XDG_SESSION_TYPE = "wayland";
        QT_QPA_PLATFORM = "wayland;xcb";
        GDK_BACKEND = "wayland,x11,*";
        MOZ_ENABLE_WAYLAND = "1";
        NIXOS_OZONE_WL = "1";
        # Let the preview daemon follow nnn's hovered path without stealing
        # keyboard focus from nnn.
        NNN_FIFO = "/run/user/1000/nnn-preview.fifo";
        # Space is remapped in the Nix-patched nnn package to open Sushi.
        # Codex Security's MCP launcher otherwise selects its cached generic
        # Linux Node runtime, which cannot run directly on NixOS.
        CODEX_MCP_NODE_PATH = "${pkgs.nodejs}/bin/node";
      };

      home.file = {
        # Keep nnn's preview entirely inside the main terminal pane. The
        # package's stock .npreview only renders PDF text and expects img2txt
        # for images, while this local version uses chafa and pdftoppm.
        ".config/nnn/plugins/.npreview" = {
          source = ./packages/nnn-preview;
          executable = true;
        };
        ".config/nnn/plugins/nuke".source = "${pkgs.nnn}/share/plugins/nuke";
        # Keep the repository-managed Codex maintenance skill discoverable by
        # Codex through the user's declarative skills directory.
        ".agents/skills/codex/SKILL.md".source = ./skills/codex/SKILL.md;
        # Wi-Fi and Bluetooth are managed by the Quickshell control center.
        # Override the system XDG autostart entries so their legacy tray
        # applets stay hidden while NetworkManager, BlueZ and the advanced
        # settings applications remain available.
        ".config/autostart/nm-applet.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Type=Application
            Name=NetworkManager Applet
            Hidden=true
          '';
        };
        ".config/autostart/blueman.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Blueman Applet
            Hidden=true
          '';
        };
        # Handy is disabled for now because its setup was not completed.
        # Keep this override so the stale profile autostart entry stays off;
        # remove it when we are ready to revisit Handy.
        ".config/autostart/Handy.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Handy
            Hidden=true
          '';
        };
        # The old profile entry was a symlink to /usr/share/applications,
        # which does not exist on NixOS. Keep Slack autostart declarative.
        ".config/autostart/slack.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Slack
            Comment=Slack Desktop
            Exec=slack
            StartupNotify=true
            Terminal=false
            X-GNOME-Autostart-enabled=true
          '';
        };
        ".local/share/applications/bitwarden.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Categories=Utility
            Comment=Secure and free password manager for all of your devices
            Exec=bitwarden --force-device-scale-factor=1.0 %U
            Icon=bitwarden
            MimeType=x-scheme-handler/bitwarden
            Name=Bitwarden
            Type=Application
            Version=1.5
          '';
        };
        ".local/share/applications/com.openai.codex.desktop".text = ''
          [Desktop Entry]
          Name=Codex
          Comment=OpenAI Codex CLI
          Exec=ghostty --class=com.openai.codex --title=Codex -e codex
          Path=/home/${labUserName}/Work
          Icon=codex
          Terminal=false
          Type=Application
          Categories=Development;Utility;
          StartupNotify=true
        '';
        ".local/share/icons/hicolor/scalable/apps/codex.svg".source = ./assets/icons/codex.svg;
        ".local/share/applications/org.retraut.nixos-rebuild.desktop".text = ''
          [Desktop Entry]
          Name=NixOS Rebuild
          Comment=Rebuild the active NixOS configuration
          Exec=ghostty --class=org.retraut.nixos-rebuild --title=NixOS Rebuild -e /home/${labUserName}/.local/bin/nixos-rebuild
          Path=/home/${labUserName}/.config/nixos
          Icon=nixos
          Terminal=false
          Type=Application
          Categories=System;Utility;
          StartupNotify=true
        '';
        ".local/share/icons/hicolor/scalable/apps/nixos.svg".source = ./assets/icons/nixos.svg;
        # GTK requires Ghostty's custom Wayland app ID to be reverse-DNS
        # formatted. A bare `nnn` is rejected and falls back to Ghostty.
        ".local/share/applications/org.retraut.nnn.desktop".text = ''
          [Desktop Entry]
          Name=nnn
          Comment=Terminal file manager with Wayland preview
          Exec=env NNN_FIFO=/run/user/1000/nnn-preview.fifo ghostty --class=org.retraut.nnn --title=nnn -e nnn
          Path=/home/${labUserName}/Work
          Icon=nnn
          Terminal=false
          Type=Application
          Categories=System;FileManager;Utility;
          StartupWMClass=org.retraut.nnn
          StartupNotify=true
        '';
        ".local/share/icons/hicolor/scalable/apps/nnn.svg".source = ./assets/icons/nnn.svg;
        ".config/autostart/bitwarden.desktop" = {
          force = true;
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Bitwarden
            Comment=Declarative scaled Bitwarden autostart
            Exec=bitwarden --force-device-scale-factor=1.0 --autostart
            StartupNotify=false
            Terminal=false
          '';
        };
        ".local/share/applications/x-com.desktop".text = ''
          [Desktop Entry]
          Name=X.com
          Comment=X.com web app
          Exec=chromium --app=https://x.com
          Icon=x-logo
          Terminal=false
          Type=Application
          Categories=Network;WebBrowser;
          StartupNotify=true
        '';
        ".local/share/icons/hicolor/scalable/apps/x-logo.svg".source = ./assets/icons/x-logo.svg;
        ".local/share/applications/youtube.desktop".text = ''
          [Desktop Entry]
          Name=YouTube
          Comment=YouTube web app
          Exec=chromium --app=https://www.youtube.com
          Icon=youtube
          Terminal=false
          Type=Application
          Categories=AudioVideo;Network;WebBrowser;
          StartupNotify=true
        '';
        ".local/share/icons/hicolor/scalable/apps/youtube.svg".source = ./assets/icons/youtube.svg;
        ".local/share/applications/gmail.desktop".text = ''
          [Desktop Entry]
          Name=Gmail
          Comment=Gmail web app
          Exec=chromium --app=https://mail.google.com/mail/u/0/
          Icon=gmail
          Terminal=false
          Type=Application
          Categories=Office;Network;WebBrowser;
          StartupNotify=true
        '';
        ".local/share/icons/hicolor/scalable/apps/gmail.svg".source = ./assets/icons/gmail.svg;
        ".config/hypr/hyprland.lua".source = ./hyprland.lua;
        ".config/hypr/hypridle.conf".source = ./hypridle.conf;
        ".config/quickshell/shell.qml".source = ./quickshell/shell.qml;
        ".config/quickshell/AppSwitcher.qml".source = ./quickshell/AppSwitcher.qml;
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
        ".local/bin/nixos-desktop-daemon" = {
          source = "${desktopDaemon}/bin/nixos-desktop-daemon";
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
        ".local/bin/nixos-menu" = {
          source = ./scripts/nixos-menu;
          executable = true;
        };
        ".local/bin/nixos-rebuild" = {
          source = ./scripts/nixos-rebuild;
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
        ".local/bin/nixos-kbd-brightness" = {
          source = ./scripts/nixos-kbd-brightness;
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
        ".local/bin/nixos-universal-paste" = {
          source = "${universalPasteHelper}/bin/nixos-universal-paste";
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
            Environment = [ userServiceEnvironment "QS_NO_RELOAD_POPUP=1" ];
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

        nixos-desktop-daemon = {
          Unit = {
            Description = "NixOS desktop state and night-shift daemon";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${desktopDaemon}/bin/nixos-desktop-daemon";
            Restart = "on-failure";
            RestartSec = 1;
            Environment = [ userServiceEnvironment ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        nnn-preview-daemon = {
          Unit = {
            Description = "Sushi preview controller for nnn";
            PartOf = [ "graphical-session.target" ];
            After = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${previewDaemon}/bin/nnn-preview-daemon";
            Restart = "on-failure";
            RestartSec = 1;
            Environment = [
              userServiceEnvironment
              "NNN_FIFO=/run/user/1000/nnn-preview.fifo"
            ];
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
