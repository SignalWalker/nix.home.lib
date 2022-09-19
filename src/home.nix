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
    flake' = assert traceVerbose "home.configuration.fromFlake(${flakeName}).flake'" true;
      sigflake.resolve {
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
              overlays = let
                expOverlays = monad.resolve (flake'.exports.${name}.overlays or []) system;
              in
                (std.traceSeq ["home.configuration.fromFlake(${flakeName})(${system}.${name}) overlays@" expOverlays] expOverlays)
                ++ (set.select (flake'.overlays or {}) ["default" system]);
            };
            depModules =
              traceVerbose "home.configuration.fromFlake(${flakeName})(${system}.${name}).depModules"
              (monad.resolve (flake'.exports.${name}.homeManagerModules or []) system);
          in
            home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              lib = pkgs.lib.extend (final: prev: {signal = self.lib;});
              modules = assert std.traceSeq ["home.configuration.fromFlake(${flakeName}})(${system}.${name}).modules depModules@" depModules] true;
                depModules
                ++ [(flake'.homeManagerModules.${name} or ({...}: {}))]
                ++ [
                  ({config, ...}: {
                    config = {
                      home.username = username;
                      home.homeDirectory = "${homeRoot}/${username}";
                    };
                  })
                ];
            }));
  package.fromHomeConfigurations = sysHomeConfigs:
    mapAttrs (system: homeConfigs:
      assert traceVerbose "home.package.fromHomeConfigurations ${system}: {${toString (attrNames homeConfigs)}}" true;
        mapAttrs (cfgName: cfg: assert traceVerbose "home.package.fromHomeConfigurations.${system} ${cfgName}" true; cfg.activationPackage) homeConfigs)
    sysHomeConfigs;
  app.fromHomeConfigurations = sysHomeConfigurations:
    std.mapAttrs (system: homeConfigurations:
      assert traceVerbose "home.app.fromHomeConfigurations ${system}: {${toString (attrNames homeConfigurations)}}" true;
        std.mapAttrs' (cfgName: cfg:
          assert traceVerbose "home.app.fromHomeConfigurations.${system} ${cfgName}" true; {
            name = "activate-${cfgName}";
            value = {
              type = "app";
              program = "${cfg.activationPackage}/activate";
            };
          })
        homeConfigurations)
    sysHomeConfigurations;
}
