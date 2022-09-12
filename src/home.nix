{
  self,
  nixpkgs,
  home-manager,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  lib = self.lib;
  home = lib.home;
  module = lib.signal.module;
  monad = lib.monad;
in {
  systems = ["x86_64-linux" "aarch64-linux"];
  linkSystemApp = pkgs: {
    app,
    pname ? "system-${app}",
    syspath ? "/usr/bin/${app}",
  }:
    pkgs.runCommandLocal pname {} ''
      mkdir -p $out/bin
      ln -sT ${syspath} $out/bin/${app}
    '';
  genConfigurations' = {
    nixpkgs,
    resolvedModules,
    username ? "ash",
    extraModules ? [],
    systems ? home.systems,
  }:
    std.genAttrs systems (system:
      std.mapAttrs (name: mod: let
        mOutputs = module.outputs.collect {module = mod;};
        pkgs = import nixpkgs {
          localSystem = builtins.currentSystem or system;
          crossSystem = system;
          overlays = mOutputs.overlays system;
        };
      in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          lib = pkgs.lib.extend (final: prev: {signal = self.lib;});
          modules =
            (monad.resolve mOutputs.homeManagerModules system)
            ++ [
              ({config, ...}: {
                config = {
                  home.username = username;
                  home.homeDirectory = "/home/${config.home.username}";
                };
              })
            ]
            ++ extraModules;
        })
      resolvedModules);
  genConfigurations = flake:
    home.genConfigurations' {
      nixpkgs = flake.inputs.nixpkgs;
      resolvedModules = mapAttrs (name: mod:
        module.resolve {
          inputs = flake.inputs;
          module = mod;
        })
      flake.signalModules;
    };
  genConfiguration = {
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
  genActivationPackages = sysHomeConfigurations:
    mapAttrs (system: homeConfigurations: mapAttrs (cfgName: cfg: cfg.activationPackage) homeConfigurations) sysHomeConfigurations;
  genActivationApp = homeConfiguration: {
    type = "app";
    program = "${homeConfiguration.activationPackage}/activate";
  };
  genActivationApps = sysHomeConfigurations:
    std.mapAttrs (system: homeConfigurations:
      std.mapAttrs' (cfgName: cfg: {
        name = "activate-${cfgName}";
        value = home.genActivationApp cfg;
      })
      homeConfigurations)
    sysHomeConfigurations;
}
