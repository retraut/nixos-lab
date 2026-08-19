{ config, pkgs, macUserName, ... }:

{
  # Apple Silicon / macOS platform adapter.
  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = macUserName;
  users.users.${macUserName} = {
    name = macUserName;
    home = "/Users/${macUserName}";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  programs.zsh.enable = true;

  # Platform-neutral CLI layer. GUI apps and casks can be added later.
  environment.systemPackages = with pkgs; [
    curl
    eza
    git
    jq
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.${macUserName} = {
      home.stateVersion = "26.05";
      home.username = macUserName;
      home.homeDirectory = "/Users/${macUserName}";

      programs.bash = {
        enable = true;
        shellAliases = {
          ls = "eza -lh --group-directories-first --icons=auto";
          lsa = "ls -a";
          ll = "eza -la";
          lt = "eza --tree --level=2 --long --icons --git";
        };
      };

      programs.git.enable = true;

      home.sessionVariables = {
        EDITOR = "vim";
        PAGER = "less -FR";
      };
    };
  };

  # Used for backwards compatibility; change only during a deliberate
  # nix-darwin migration.
  system.stateVersion = 6;
}
