{ lib, path }:

let
  modulesPath = "${builtins.storePath path}/nixos/modules";

  mkImportPath = path: if builtins.typeOf path == "string"
    then "${modulesPath}/${path}"
    else path;

  libOverlay = self: super: {
    mkImports = paths: builtins.map mkImportPath paths;
  };

in (lib.extend libOverlay).evalModules {
  modules = [
    ./boot.nix
    ./hardware.nix
    ./init.nix
    ./nixos.nix
    ./openpgp.nix
  ];

  specialArgs = {
    inherit modulesPath;
  };
}

