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
      overlays.default = final: prev: {
      };
      lib = {
        utils = import ./src/utils.nix {inherit (flakeInputs) nixpkgs;};
        fs = import ./src/fs.nix;
        mkDefaultEnableOption = name: (std.mkEnableOption name) // {default = true;};
        hmSystems = ["x86_64-linux" "aarch64-linux"];
        linkSystemApp = pkgs: {
          app,
          pname ? "system-${app}",
          syspath ? "/usr/bin/${app}",
        }:
          pkgs.runCommandLocal pname {} ''
            mkdir -p $out/bin
            ln -sT ${syspath} $out/bin/${app}
          '';
        genNixpkgsForList = {
          nixpkgs,
          overlays,
          systems,
        }:
          self.lib.genNixpkgsForFn {
            inherit nixpkgs systems;
            overlayFn = system: overlays;
          };
        genNixpkgsForFn = {
          nixpkgs,
          overlayFn,
          systems,
        }:
          std.genAttrs systems (system:
            import nixpkgs {
              localSystem = builtins.currentSystem or system;
              crossSystem = system;
              overlays = overlayFn system;
            });
        genNixpkgsFor = inputs @ {
          nixpkgs,
          overlays ? [],
          systems ? self.lib.hmSystems,
        }:
          if isList overlays
          then genNixpkgsForList inputs
          else genNixpkgsForFn inputs;
        mergeOverlays = overlays: foldl' (acc: overlay: (final: prev: (acc final prev) // (overlay final prev))) (final: prev: {}) overlays;
        selectOverlays' = flake: names: foldl' (acc: name: acc ++ (flake.lib.overlays.${name} or [])) [] (names);
        collectInputAttrs = top: nxt: inputs:
          foldl' (
            acc: i:
              acc ++ (std.optional (i ? ${top} && i ? ${top}.${nxt}) i.${top}.${nxt})
          ) []
          inputs;
        collectInputModules' = self.lib.collectInputAttrs "homeManagerModules";
        collectInputModules = self.lib.collectInputModules' "default";
        collectInputOverlays' = self.lib.collectInputAttrs "overlays";
        collectInputOverlays = self.lib.collectInputOverlays' "default";
        aggregateOverlays = inputs: foldl' (acc: input: acc // (std.mapAttrs (name: overlay: (acc.${name} or []) ++ [overlay]) (input.overlays or {}))) {} inputs;
        genHomeConfiguration = {
          pkgs,
          modules ? [],
          username ? "ash",
        }:
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            lib = pkgs.lib.extend (final: prev: {signal = self.lib;});
            modules =
              modules
              ++ [
                ({config, ...}: {
                  config = {
                    home.username = username;
                    home.homeDirectory = "/home/${config.home.username}";
                  };
                })
              ];
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
