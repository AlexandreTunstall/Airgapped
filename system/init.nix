{ config, lib, pkgs, ... }:
let
  mkService = svName: name: value: lib.nameValuePair "service/${svName}/${name}" (builtins.toString value);
  s6-run-image = pkgs.symlinkJoin {
    name = "s6-run-image";
    paths = lib.mapAttrsToList (_: value: value.build) config.s6.services;
  };

  s6-scripts = pkgs.linkFarm "s6-scripts" {
    "rc.init" = pkgs.writeShellScript "rc.init" ''
      printf 'Booted, press Ctrl+Alt+F2 to access the console\n'
    '';

    "rc.shutdown" = pkgs.writeShellScript "rc.shutdown" "";
    "rc.shutdown.final" = pkgs.writeShellScript "rc.shutdown.final" "";
  };

  loginProg = pkgs.writeShellScript "getty-login" ''
    if ! [ "$1" = -f ]; then
      printf 'Usage: login -f user\n' >&2
      exit 1
    fi
    export HOME=/run/user
    exec ${pkgs.s6}/bin/s6-setuidgid "$2" /sw/bin/bash
  '';
in
{
  options.s6 = {
    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, name, ... }: {
        options = {
          notification-fd = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            description = "The file descriptor the service will use to notify readiness.";
            default = null;
          };

          run = lib.mkOption {
            type = lib.types.package;
            description = "The service's run command.";
            default = pkgs.writeScript "${name}-run.sh" ''
              #!${pkgs.execline}/bin/execlineb -P
              ${config.runScript}
            '';
          };

          runScript = lib.mkOption {
            type = lib.types.lines;
            description = "The service's run script.";
          };

          build = lib.mkOption {
            type = lib.types.package;
            description = "The fully built service.";
            default = pkgs.linkFarm name (lib.mapAttrs' (mkService name) (lib.filterAttrs (_: v: v != null) {
              inherit (config) run;

              notification-fd = if config.notification-fd != null
                then pkgs.writeText "${name}-notification-fd"
                  (builtins.toString config.notification-fd)
                else null;
            }));
          };
        };
      }));
    };
  };

  config = {
    boot.kernelParams = [
      "init=/init"
    ];

    environment = {
      etc."init/scripts".source = s6-scripts;

      systemPackages = lib.mkForce [
        pkgs.bashInteractive
        pkgs.s6
        pkgs.s6-linux-init
        pkgs.s6-linux-utils
      ];
    };

    system.build.init = pkgs.writeScript "init" ''
      #!/sw/bin/sh

      printf 'Populating /etc/init/run-image\n'
      /sw/bin/mkdir -p /etc/init/env
      /sw/bin/cp -r --preserve=all ${s6-run-image} /etc/init/run-image
      /sw/bin/mkfifo /etc/init/run-image/service/s6-svscan-log/fifo
      /sw/bin/mkfifo /etc/init/run-image/service/s6-linux-init-shutdownd/fifo
      printf 'Mounting /run\n'
      /sw/bin/mkdir -m 0755 /run
      /sw/bin/s6-mount -t tmpfs -o rw,noexec,nosuid,nodev /dev/null /run
      /sw/bin/mkdir -m 0755 /run/uncaught-logs
      /sw/bin/chown 1:1 /run/uncaught-logs
      /sw/bin/mkdir -m 0700 /run/user
      /sw/bin/chown 2:2 /run/user
      printf 'Remounting / read-only\n'
      /sw/bin/s6-mount -o remount,ro /dev/null /
      exec /sw/bin/s6-linux-init -N -c /etc/init -m 0077 -p /sw/bin -d /dev -- "$@"
    '';

    system.requiredKernelConfig = with config.lib.kernelConfig; [
      (isYes "BLK_DEV_INITRD")
      (isYes "DEVTMPFS")
      (isYes "TMPFS")
    ];

    s6.services = {
      getty.runScript = ''
        ${pkgs.mingetty}/bin/mingetty --noclear tty2 --autologin 0:0 --loginprog ${loginProg}
      '';

      s6-linux-init-shutdownd.runScript = ''
        ${pkgs.s6-linux-init}/bin/s6-linux-init-shutdownd -c /etc/init -g 3000
      '';

      s6-svscan-log = {
        runScript = ''
          ${pkgs.execline}/bin/fdmove -c 1 2
          ${pkgs.execline}/bin/redirfd -rnb 0 fifo
          ${pkgs.s6}/bin/s6-setuidgid "1:1"
          ${pkgs.s6}/bin/s6-log -bpd3 -- 1 t /run/uncaught-logs
        '';

        notification-fd = 3;
      };
    };
  };
}
