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
  outputs = flakeInputs @ {
    self,
    home-manager,
    ...
  }:
    with builtins; let
      std = flakeInputs.nixpkgs.lib;
    in {
      formatter = std.mapAttrs (system: pkgs: pkgs.default) flakeInputs.alejandra.packages;
      lib = {
        utils = import ./src/utils.nix {inherit (flakeInputs) nixpkgs;};
        fs = import ./src/fs.nix;
        hmSystems = ["x86_64-linux" "aarch64-linux"];
        genNixpkgsFor = {
          nixpkgs,
          systems ? self.lib.hmSystems,
          overlays ? [],
        }:
          std.genAttrs systems (system:
            import nixpkgs {
              localSystem = builtins.currentSystem or system;
              crossSystem = system;
              inherit overlays;
            });
        collectInputModules' = moduleName: inputs:
          foldl' (
            acc: i:
              acc ++ (std.optional (i ? homeManagerModules && i ? homeManagerModules.${moduleName}) i.homeManagerModules.${moduleName})
          ) [] (attrValues inputs);
        collectInputModules = self.lib.collectInputModules' "default";
        genHomeConfiguration = {
          pkgs,
          inputs,
          extraModules ? [],
          username ? "ash",
          ...
        }:
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            lib = pkgs.lib.extend (final: prev: {signal = self.lib;});
            modules =
              (self.lib.collectInputModules inputs)
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
          mapAttrs (system: homeConfigurations: mapAttrs (cfgName: cfg: cfg.activationPackage) homeConfigurations) sysHomeConfigurations;
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
