{
  self,
  nixpkgs,
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
  configuration.genArgsFromFlake = {
    flake',
    signalModuleName,
    crossSystem,
    extraModules ? {
      crossSystem,
      moduleName,
    }: [],
    localSystem ? builtins.currentSystem or crossSystem,
    exports ? (signal.flake.resolved.exports {inherit flake' crossSystem;}).${signalModuleName},
    home-manager ? flake'.inputs.home-manager,
    selfOverlays ? set.select (flake'.overlays or {}) ["default" crossSystem signalModuleName],
    nixpkgs ? flake'.inputs.nixpkgs,
    nixpkgs' ?
      signal.flake.resolved.nixpkgs {
        inherit nixpkgs flake' signalModuleName crossSystem selfOverlays;
        exportedOverlays = exports.overlays;
      },
    pkgsLibExtended ? signal.flake.resolved.stdlib {inherit nixpkgs';},
  }: {
    system = crossSystem;
    pkgs = nixpkgs';
    lib = pkgsLibExtended;
    modules =
      (exports.nixosModules or [])
      (monad.resolve extraModules {
        inherit crossSystem;
        moduleName = signalModuleName;
      })
      ++ [
        ({
          config,
          lib,
          ...
        }: {
          config = {
            networking.hostName = lib.mkDefault (hostNameMap.${modName} or hostNameMap.__default or modName);
            home-manager = {
              sharedModules =
                (exports.homeManagerModules or [])
                ++ (set.select (flake'.homeManagerModules or {}) ["default" crossSystem signalModuleName])
                ++ [
                  ({...}: {
                    config = {
                      system.isNixOS = true;
                    };
                  })
                ];
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
    extraModules ? [],
    hostNameMap ? {},
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
          "${crossSystem}-${modName}" = nixpkgs.lib.nixosSystem (sys.configuration.genArgsFromFlake {
            inherit
              flake'
              crossSystem
              extraModules
              home-manager
              ;
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
