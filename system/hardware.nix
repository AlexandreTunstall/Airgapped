{ config, lib, pkgs, ... }:

let
  system = {
    config = "aarch64-unknown-linux-musl";
    isStatic = true;

    linux-kernel = {
      name = "raspberrypi3b";

      baseConfig = "bcm2835_defconfig";
      DTB = true;
      autoModules = true;
      preferBuiltin = true;

      extraConfig = ''
        # OABI_COMPAT n

        ARCH_BCM_2835 y
        BCM_2835_MBOX y
        BCM_2835_WDT y
        RASPBERRYPI_FIRMWARE y
        RASPBERRYPI_POWER y
        SERIAL_8250_BCM2835AUX y
        SERIAL_8250_EXTENDED y
        SERIAL_8250_SHARE_IRQ y
      '';

      target = "Image";
    };

    gcc.arch = "armv8-a";
  };

  boot-config = pkgs.writeText "config.txt" ''
    kernel=u-boot-rpi3.bin
    arm_64bit=1
    enable_uart=1
    avoid_warnings=1
  '';

in {
  imports = lib.mkImports [
    "installer/sd-card/sd-image.nix"
    "system/boot/loader/generic-extlinux-compatible"
  ];

  disabledModules = [
    "profiles/all-hardware.nix"
  ];

  config = {
    nixpkgs = {
      buildPlatform = builtins.currentSystem;
      hostPlatform = system;

      overlays = [
        (self: super: {
          mingetty = super.mingetty.overrideAttrs (old: {
            preBuild = ''
              sed -i '/^CC=gcc$/d' Makefile
              ${old.preBuild or ""}
            '';
          });
        })
      ];
    };

    boot = {
      kernelPackages = pkgs.linuxPackages_rpi3;
      loader.generic-extlinux-compatible.enable = true;
    };

    sdImage = {
      populateFirmwareCommands = ''
        cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/{bootcode.bin,fixup*.dat,start*.elf} $NIX_BUILD_TOP/firmware/
        cp ${boot-config} firmware/config.txt
        cp ${pkgs.ubootRaspberryPi3_64bit}/u-boot.bin firmware/u-boot-rpi3.bin
      '';

      populateRootCommands = ''
        mkdir -p ./files/boot
        ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
      '';

      storePaths = lib.mkForce [];

      expandOnBoot = false;
    };
  };
}
