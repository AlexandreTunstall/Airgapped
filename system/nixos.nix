{ config, lib, pkgs, ... }:

let
  dudOption = lib.mkOption {
    type = lib.types.anything;
    default = null;
    description = "Unused";
  };

in {
  imports = lib.mkImports [
    "config/sysctl.nix"
    "config/system-path.nix"
    "hardware/device-tree.nix"
    "misc/assertions.nix"
    "misc/lib.nix"
    "misc/nixpkgs.nix"
    "misc/version.nix"
    "system/boot/kernel.nix"
    "system/boot/loader/loader.nix"
    "system/etc/etc.nix"
  ];

  options = {
    fileSystems = dudOption;
    networking = dudOption;
    systemd = dudOption;

    # TODO: These options should probably be honoured in some way.
    boot.postBootCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
  };

  config = {
    environment.systemPackages = lib.mkForce [
      # I'd like to use dash instead, but it doesn't build. :(
      pkgs.bash
      pkgs.coreutils-full
    ];

    networking.hostName = "airgapped";
    system.build.earlyMountScript = "";

    system.stateVersion = config.system.nixos.release;
  };
}
