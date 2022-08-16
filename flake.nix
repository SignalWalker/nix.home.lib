{
  description = "Library for home-manager flakes";
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixpkgs-unstable;
    alejandra = {
      url = github:kamadorueda/alejandra;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = github:nix-community/home-manager;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    ...
  }:
    with builtins; let
      std = nixpkgs.lib;
    in {
      formatter = std.mapAttrs (system: pkgs: pkgs.default) inputs.alejandra.packages;
      lib = {
        utils = import ./src/utils.nix {inherit nixpkgs;};
        fs = import ./src/fs.nix;
        hmSystems = attrNames home-manager.packages;
        collectInputModules' = moduleName: flakeInputs: foldl' (acc: i: acc ++ (std.optional (i ? homeManagerModules && i ? homeManagerModules.${moduleName}) i.homeManagerModules.${moduleName})) [] flakeInputs;
        collectInputModules = self.lib.collectInputModules' "default";
        genHomeConfiguration = {
          pkgs,
          flakeInputs,
          extraModules ? [],
          username ? "ash",
          ...
        }:
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules =
              (self.lib.collectInputModules flakeInputs)
              ++ [
                ({config, ...}: {
                  config = {
                    home.username = username;
                    home.homeDirectory = "/home/${config.home.username}";
                  };
                })
              ]
              ++ extraModules;
          };
        genHomeActivationPackages = sysHomeConfigurations:
          std.mapAttrs (system: homeConfigurations: std.mapAttrs (cfgName: cfg: cfg.activationPackage) homeConfigurations);
        genHomeActivationApp = homeConfiguration: {
          type = "app";
          program = "${homeConfiguration.activationPackage}/activate";
        };
        genHomeActivationApps = sysHomeConfigurations:
          std.mapAttrs (system: homeConfigurations:
            std.mapAttrs' (cfgName: cfg: {
              name = "activate-${cfgName}";
              value = self.lib.genHomeActivationApp cfg;
            })
            homeConfigurations)
          sysHomeConfigurations;
      };
    };
}
