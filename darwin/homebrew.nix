{ ... }:

{
  # Optional macOS GUI layer. Keep these out of the NixOS package set so the
  # Linux VM/laptop profiles stay fully reproducible with native packages.
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };

    brews = [ ];
    casks = [
      "ghostty"
      "chromium"
      "bitwarden"
    ];
  };
}
