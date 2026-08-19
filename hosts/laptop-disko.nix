{
  disko.devices.disk.main = {
    type = "disk";

    # Deliberately unusable by default. scripts/install-laptop must override
    # this with `--disk main /dev/disk/by-id/...` after validating the device.
    device = "/dev/disk/by-id/NVME_TARGET_MUST_BE_OVERRIDDEN";

    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [ "-n" "NIXOS_EFI" ];
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        encrypted = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            askPassword = true;
            settings.allowDiscards = true;
            extraFormatArgs = [
              "--type"
              "luks2"
              "--label"
              "NIXOS_CRYPT"
            ];

            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-L" "NIXOS_ROOT" ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                    "discard=async"
                  ];
                };
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                    "discard=async"
                  ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                    "discard=async"
                  ];
                };
                "/log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                    "ssd"
                    "discard=async"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
