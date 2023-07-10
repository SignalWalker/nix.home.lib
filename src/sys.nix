{
  self,
  nixpkgs,
  home-manager,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  sys = self.lib.sys;
  list = self.lib.list;
  monad = self.lib.monad;
  set = self.lib.set;
  signal = self.lib.signal;
in {
  crossSystems = ["x86_64-linux" "aarch64-linux"];
  # Generate argument map for `nixpkgs.lib.nixosSystem`
  configuration.genArgsFromFlake' = {
    # Output from `signal.flake.resolve`
    flake',
    # signalModule from which to generate arguments
    signalModuleName,
    # target system
    crossSystem,
    extraNixosModules ? {
      crossSystem,
      moduleName,
    }: [],
    extraHomeModules ? {
      crossSystem,
      moduleName,
    }: [],
    localSystem ? builtins.currentSystem or crossSystem,
    exports ? (signal.flake.resolved.exports {inherit flake' crossSystem;}).${signalModuleName},
    selfOverlays ? set.select (flake'.overlays or {}) ["default" crossSystem signalModuleName],
    nixpkgs ? flake'.inputs.nixpkgs,
    nixpkgs' ?
      signal.flake.resolved.nixpkgs {
        inherit nixpkgs flake' signalModuleName crossSystem selfOverlays;
        exportedOverlays = exports.overlays;
      },
    pkgsLibExtended ? signal.flake.resolved.stdlib {inherit nixpkgs';},
    home-manager ? flake'.inputs.home-manager or home-manager,
    homeManagerModules ?
      (self.lib.home.configuration.genModulesFromFlake' {
        inherit flake' signalModuleName crossSystem localSystem exports;
        isNixOS = true;
      })
      ++ (monad.resolve extraHomeModules {
        inherit crossSystem;
        moduleName = signalModuleName;
      }),
  }: {
    system = crossSystem;
    pkgs = nixpkgs';
    lib = pkgsLibExtended;
    modules =
      (exports.nixosModules or [])
      ++ (monad.resolve extraNixosModules {
        inherit crossSystem;
        moduleName = signalModuleName;
      })
      ++ (set.select (flake'.nixosModules or {}) ["default" crossSystem signalModuleName])
      ++ [
        ({
          config,
          lib,
          ...
        }: {
          config = {
            home-manager = {
              sharedModules = homeManagerModules;
              extraSpecialArgs.lib = import "${home-manager}/modules/lib/stdlib-extended.nix" pkgsLibExtended;
              useGlobalPkgs = true;
              useUserPackages = true;
            };
          };
        })
      ];
  };
  configuration.fromFlake = {
    flake,
    flakeName ? "<unknown>",
    nixpkgs ? flake.inputs.nixpkgs,
    home-manager ? flake.inputs.home-manager,
    localSystem ? null,
    crossSystems ? sys.crossSystems,
    extraNixosModules ? {
      crossSystem,
      moduleName,
    }: [],
    extraHomeModules ? {
      crossSystem,
      moduleName,
    }: [],
  }: let
    flake' = self.lib.signal.flake.resolve {
      inherit flake;
      name = flakeName;
    };
  in
    foldl' (sysAcc: crossSystem: let
      exports = signal.flake.resolved.exports {inherit flake' crossSystem;};
    in
      foldl' (modAcc: modName:
        modAcc
        // {
          "${crossSystem}-${modName}" = nixpkgs.lib.nixosSystem (sys.configuration.genArgsFromFlake' {
            inherit
              flake'
              crossSystem
              home-manager
              ;
            inherit extraNixosModules extraHomeModules;
            exports = exports.${modName};
            localSystem =
              if localSystem != null
              then localSystem
              else builtins.currentSystem or crossSystem;
            signalModuleName = modName;
          });
        })
      sysAcc (attrNames flake'.nixosModules)) {}
    crossSystems;
}
