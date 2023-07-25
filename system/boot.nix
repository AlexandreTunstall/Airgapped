{ config, lib, pkgs, ... }:
{
  options.system.boot.loader = {
    id = lib.mkOption {
      type = lib.types.str;
      default = "";
    };

    kernelFile = lib.mkOption {
      type = lib.types.str;
      default = pkgs.stdenv.hostPlatform.linux-kernel.target;
    };

    initrdFile = lib.mkOption {
      type = lib.types.str;
      default = "initrd";
    };
  };

  config.system.build = {
    toplevel = pkgs.stdenvNoCC.mkDerivation {
      name = "nixos-system-airgapped-${config.system.nixos.label}";
      preferLocalBuild = true;

      buildCommand = let
        kernelPath = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
        initrdPath = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
      in ''
        mkdir $out

        ln -s ${kernelPath} $out/kernel
        ln -s ${config.system.modulesTree} $out/kernel-modules
        ln -s ${config.hardware.deviceTree.package} $out/dtbs

        echo -n "$kernelParams" > $out/kernel-params

        ln -s ${initrdPath} $out/initrd

        echo -n "$nixosLabel" > $out/nixos-version

        cp ${config.system.build.init} $out/init
      '';

      kernelParams = config.boot.kernelParams;
      nixosLabel = config.system.nixos.label;
    };

    initialRamdisk = pkgs.makeInitrd {
      name = "initrd-${config.boot.kernelPackages.kernel.name or "kernel"}";

      contents = [
        {
          object = config.system.build.init;
          symlink = "/init";
        }
        {
          object = config.system.path;
          symlink = "/sw";
        }
        {
          object = "${config.system.build.etc}/etc";
          symlink = "/etc";
        }
      ];
    };
  };
}
