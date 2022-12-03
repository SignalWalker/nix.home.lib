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
in {
  crossSystems = ["x86_64-linux" "aarch64-linux"];
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
    foldl' (sysAcc: crossSystem:
      foldl' (modAcc: modName: let
        selfHmModules = set.select (flake'.homeManagerModules or {}) ["default" crossSystem modName];
        pkgs = self.lib.signal.flake.resolved.nixpkgs {
          inherit nixpkgs flake' crossSystem selfOverlays;
          localSystem =
            if localSystem != null
            then localSystem
            else builtins.currentSystem or crossSystem;
          signalModuleName = modName;
        };
        pkgsLibExtended = pkgs.lib.extend (final: prev: {signal = self.lib;});
        depModules = monad.resolve (flake'.exports.${modName}.nixosModules or []) crossSystem;
        extraModules' = monad.resolve extraModules {
          inherit crossSystem;
          moduleName = modName;
        };
        depHmModules = monad.resolve (flake'.exports.${modName}.homeManagerModules or []) crossSystem;
      in
        modAcc
        // {
          "${crossSystem}-${modName}" = nixpkgs.lib.nixosSystem {
            system = crossSystem;
            lib = pkgsLibExtended;
            inherit pkgs;
            modules =
              depModules
              ++ [
                flake'.nixosModules.${modName}
                ({lib, ...}: {
                  config = {
                    networking.hostName = lib.mkDefault (hostNameMap.${modName} or hostNameMap.__default or modName);
                    home-manager = {
                      sharedModules =
                        depHmModules
                        ++ selfHmModules
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
              ]
              ++ extraModules';
          };
        })
      sysAcc (attrNames flake'.nixosModules)) {}
    crossSystems;
}
