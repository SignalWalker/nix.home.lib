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
  sigflake = lib.signal.flake;
  monad = lib.monad;
  set = lib.set;
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
  configuration.fromFlake = {
    flake,
    nixpkgs ? flake.inputs.nixpkgs,
    homeRoot ? "/home",
    username ? "ash",
    moduleNames ? ["default"],
    systems ? home.systems,
    flakeName ? "<unknown>",
  }: let
    flake' = sigflake.resolve {
      inherit flake;
      name = flakeName;
    };
  in
    assert traceVerbose "home.configuration.fromFlake ${flakeName}" true;
      std.genAttrs systems (system:
        std.genAttrs moduleNames (name:
          assert traceVerbose "home.configuration.fromFlake(${flakeName}) ${system}.${name}" true; let
            pkgs = import nixpkgs {
              localSystem = builtins.currentSystem or system;
              crossSystem = system;
              overlays =
                (
                  if flake ? "exports" && flake.exports ? ${name}
                  then monad.resolve (flake.exports.${name}.overlays or []) system
                  else []
                )
                ++ (set.select (flake.overlays or {}) ["default" system]);
            };
            depModules =
              if flake ? "exports" && flake.exports ? ${name}
              then monad.resolve (flake.exports.${name}.homeManagerModules or []) system
              else [];
          in
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              lib = pkgs.lib.extend (final: prev: {signal = self.lib;});
              modules =
                depModules
                ++ (
                  if flake' ? "homeManagerModules" && flake'.homeManagerModules ? ${name}
                  then [flake'.homeManagerModules.${name}]
                  else []
                )
                ++ [
                  ({config, ...}: {
                    config = {
                      home.username = username;
                      home.homeDirectory = "${homeRoot}/${username}";
                    };
                  })
                ];
            }));
  package.fromHomeConfigurations = sysHomeConfigs: assert traceVerbose "home.package.fromHomeConfigurations {${toString (attrNames sysHomeConfigs)}}" true; mapAttrs (system: homeConfigs: mapAttrs (cfgName: cfg: cfg.activationPackage) homeConfigs) sysHomeConfigs;
  app.fromHomeConfigurations = sysHomeConfigurations:
    assert traceVerbose "home.package.fromHomeConfigurations {${toString (attrNames sysHomeConfigs)}}" true;
      std.mapAttrs (system: homeConfigurations:
        std.mapAttrs' (cfgName: cfg: {
          name = "activate-${cfgName}";
          value = {
            type = "app";
            program = "${cfg.activationPackage}/activate";
          };
        })
        homeConfigurations)
      sysHomeConfigurations;
}
