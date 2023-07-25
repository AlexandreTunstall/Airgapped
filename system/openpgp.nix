{ lib, pkgs, ... }:
{
  config = {
    environment.systemPackages = lib.mkForce [
      pkgs.gnupg
      # To mount key backups
      pkgs.mdadm
    ];

    nixpkgs.overlays = [
      (self: super: {
        gnupg = super.gnupg.override {
          withPcsc = false;
          withTpm2Tss = false;
          openldap = null;
        };

        mdadm = (super.mdadm.override {
          groff = null;
          udev = null;
        }).overrideAttrs (old: {
          buildFlags = [ "CXFLAGS=-DNO_LIBUDEV" "CWFLAGS=" ];
          installFlags = [ "install-bin" ];
          postPatch = "";
        });
      })
    ];
  };
}
