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
      utils = import ./src/utils.nix {inherit (flakeInputs) nixpkgs;};
    in {
      inputs = flakeInputs;
      formatter = std.mapAttrs (system: pkgs: pkgs.default) flakeInputs.alejandra.packages;
      templates = {
        home = {
          path = ./templates/home;
          description = "A simple home-manager flake using signal modules";
        };
        sys = {
          path = ./templates/sys;
          description = "A simple NixOS configuration flake using signal modules";
        };
      };
      lib = {
        enum = import ./src/enum.nix flakeInputs;
        fs = import ./src/fs.nix flakeInputs;
        home = import ./src/home.nix flakeInputs;
        list = import ./src/list.nix flakeInputs;
        meta = import ./src/meta.nix flakeInputs;
        monad = import ./src/monad.nix flakeInputs;
        set = import ./src/set.nix flakeInputs;
        signal = import ./src/signal.nix flakeInputs;
        sys = import ./src/sys.nix flakeInputs;
        inherit utils;
        option = import ./src/option.nix flakeInputs;
        mkDefaultEnableOption = name: (std.mkEnableOption name) // {default = true;};
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
          systems ? self.lib.home.systems,
        }:
          if isList overlays
          then self.lib.genNixpkgsForList {inherit nixpkgs overlays systems;}
          else
            self.lib.genNixpkgsForFn {
              inherit nixpkgs systems;
              overlayFn = overlays;
            };
        resolveDependencies = {
          inputs,
          filter ? [],
          resolveFn ? (incumbent: challenger:
            if incumbent.lastModified >= challenger.lastModified
            then incumbent
            else challenger),
        }:
          foldl' (acc: inputName: let
            input = inputs.${inputName};
          in
            acc
            // (std.mapAttrs (dName: dep:
              if acc ? ${dName}
              then resolveFn acc.${dName} dep
              else dep)
            (input.dependencies or {}))) (removeAttrs inputs (filter ++ ["self"])) (attrNames inputs);
        collectSelfAndDepOverlays = flake: overlayNames: self.lib.set.selectFrom (map (flake: flake.overlays or {}) ([flake] ++ (attrValues flake.dependencies))) overlayNames;
        zipFlakeOverlays = inputs: zipAttrsWith (name: values: values) (map (input: input.overlays or {}) inputs);
        zipLibOverlays = inputs: zipAttrsWith (name: values: concatLists values) (map (input: input.lib.overlays or {}) inputs);
        zipOverlays = {
          inputs,
          libFilter ? ["self"],
          flakeFilter ? ["nixpkgs"],
        }:
          foldl' (acc: inputName: let
            input = inputs.${inputName};
            inputLibOverlays =
              if elem inputName libFilter
              then {}
              else input.lib.overlays or {};
            libOverlays = self.lib.concatAttrs acc inputLibOverlays;
            inputFlakeOverlays =
              if elem inputName flakeFilter
              then {}
              else input.overlays or {};
          in
            self.lib.set.append libOverlays inputFlakeOverlays) {} (attrNames inputs);
        mergeOverlays = overlays: (final: prev: foldl' (acc: overlay: acc // (overlay final prev)) {} overlays);
        aggregateOverlays = {
          inputs,
          filter ? ["self"],
        }:
          foldl' (acc: inputName: let
            input = inputs.${inputName};
          in
            if elem inputName filter
            then acc
            else (zipAttrsWith (key: values: self.lib.mergeOverlays values) [acc (input.overlays or {})])) {} (attrNames inputs);
        collectInputAttrs = top: nxt: inputs:
          foldl' (
            acc: i:
              acc ++ (std.optional (i ? ${top} && i ? ${top}.${nxt}) i.${top}.${nxt})
          ) []
          inputs;
        # exportFlakes = { flakes, filter = [ "self" ] }: foldl' () ;
        collectInputModules' = self.lib.collectInputAttrs "homeManagerModules";
        collectInputModules = self.lib.collectInputModules' "default";
        collectInputOverlays' = self.lib.collectInputAttrs "overlays";
        collectInputOverlays = self.lib.collectInputOverlays' "default";
      };
    };
}
