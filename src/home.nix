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
  signal = lib.signal;
  module = lib.signal.module;
  sigflake = lib.signal.flake;
  monad = lib.monad;
  set = lib.set;
  option = lib.option;
in {
  crossSystems = ["x86_64-linux" "aarch64-linux"];
  linkSystemApp = pkgs: {
    app,
    pname ? "system-${app}",
    syspathBase ? "/usr/bin",
    syspath ? "${syspathBase}/${app}",
    extraApps ? [],
    extraArgs ? {},
  }:
    pkgs.runCommandLocal pname extraArgs (''
        mkdir -p $out/bin
        ln -sT ${syspath} $out/bin/${app}
      ''
      + (concatStringsSep "\n" (map (app: "ln -sT ${syspathBase}/${app} $out/bin/${app}") extraApps)));
  configuration.genModulesFromFlake' = {
    flake',
    signalModuleName,
    crossSystem,
    isNixOS ? true,
    localSystem ? builtins.currentSystem or crossSystem,
    exports ? (signal.flake.resolved.exports {inherit flake' crossSystem;}).${signalModuleName},
  }:
    (exports.homeManagerModules or [])
    ++ (set.select (flake'.homeManagerModules or {}) ["default" crossSystem signalModuleName])
    ++ [({...}: {config.system.isNixOS = isNixOS;})];
  configuration.genArgsFromFlake' = {
    flake',
    signalModuleName,
    crossSystem,
    isNixOS ? true,
    allowUnfree,
    extraModules ? {
      crossSystem,
      moduleName,
    }: [],
    localSystem ? builtins.currentSystem or crossSystem,
    exports ? (signal.flake.resolved.exports {inherit flake' crossSystem;}).${signalModuleName},
    selfOverlays ? set.select (flake'.overlays or {}) ["default" crossSystem signalModuleName],
    nixpkgs ? flake'.inputs.nixpkgs,
    nixpkgs' ?
      signal.flake.resolved.nixpkgs {
        inherit nixpkgs flake' signalModuleName crossSystem selfOverlays allowUnfree;
        exportedOverlays = exports.overlays;
      },
    pkgsLibExtended ? signal.flake.resolved.stdlib {inherit nixpkgs';},
    extraSpecialArgs ? {},
  }: {
    pkgs = nixpkgs';
    lib = pkgsLibExtended;
    modules =
      (home.configuration.genModulesFromFlake' {inherit flake' signalModuleName crossSystem localSystem exports isNixOS;})
      ++ (monad.resolve extraModules {
        inherit crossSystem;
        moduleName = signalModuleName;
      });
    inherit extraSpecialArgs;
  };
  configuration.fromFlake = {
    flake,
    isNixOS ? true,
    allowUnfree,
    flakeName ? "<unknown>",
    moduleNames ? ["default"],
    crossSystems ? home.crossSystems,
    localSystem ? builtins.currentSystem or null,
    extraModules ? {
      crossSystem,
      moduleName,
    }: [],
    home-manager ? flake.inputs.home-manager or home-manager,
  }: let
    flake' = sigflake.resolve {
      inherit flake;
      name = flakeName;
    };
  in
    std.genAttrs crossSystems (
      crossSystem: let
        localSystem = option.unwrapOr localSystem crossSystem;
      in
        std.genAttrs moduleNames (
          signalModuleName:
            home-manager.lib.homeManagerConfiguration (home.configuration.genArgsFromFlake' {
              inherit flake' signalModuleName crossSystem extraModules localSystem isNixOS allowUnfree;
              inherit (flake'.inputs) nixpkgs;
            })
        )
    );
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
