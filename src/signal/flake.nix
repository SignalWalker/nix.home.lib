{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  meta = self.lib.meta;
  monad = self.lib.monad;
  set = self.lib.set;
  signal = self.lib.signal;
  dependency = signal.dependency;
  module = signal.module;
in {
  dependencies.get = flake:
  # for each signalModule "mod" in flake:
  #   res = dependency.set.merge res (module.toDependencies { inherit inputs; module = mod; })
  # return res
    foldl' (res: modName:
      dependency.set.merge res (module.dependencies.collect {
        inputs = flake.inputs;
        module = flake.signalModules.${modName};
      })) {} (attrNames (flake.signalModules or {}));
  toDependencies = {
    flake,
    name,
    outputs ? {
      homeManagerModules = ["default"];
      overlays = system: ["default" system];
    },
  }:
    assert traceVerbose "flake.toDependencies ${name}" true;
      dependency.set.merge (signal.flake.dependencies.get flake) {
        ${name} = {
          input = flake;
          inherit outputs;
        };
      };
  set.toDependencies = {
    flakes,
    filter ? [],
    inputs ? flakes,
    outputs ? {
      homeManagerModules = ["default"];
      overlays = system: ["default" system];
    },
  }: let
    flakes' = removeAttrs flakes (["self"] ++ filter);
    inputs' = removeAttrs flakes ["self"];
  in
    foldl' (res: name: let
      flake = flakes'.${name};
    in
      dependency.set.merge res (signal.flake.toDependencies {
        inputs = inputs';
        inherit flake name outputs;
      })) {} (attrNames flakes');
  resolve = {
    flake,
    name ? "<unknown>",
  }:
    assert traceVerbose "flake.resolve ${name}" true;
    assert (attrNames (flake.signalModules or {"default" = {};})) == ["default"]; # otherwise unsupported
    
      let
        flakeDeps = signal.flake.dependencies.get flake;
        flakeRes = signal.flake.resolve' {
          inherit flake name;
          dependencies = flakeDeps;
        };
        flake = flakeRes.flake;
        resDeps = flakeRes.resolvedDependencies;
      in
        flake // {exports.default = foldl' (acc: depName: set.concat acc resDeps.${depName}.outputs) (flake.exports.default or {}) (attrNames flakeDeps);};
  resolve' = {
    dependencies,
    flake,
    name ? "<unknown>",
  }:
    assert traceVerbose "flake.resolve' ${name}" true;
      if !(flake ? signalModules)
      then flake
      else
        (foldl' (res: modName: let
            modRes = module.resolve' {
              dependencies = dependencies // res.resolvedDependencies;
              module = flake.signalModules.${modName};
              name = "${name}.${modName}";
            };
            mod = modRes.module;
            resolvedDeps = modRes.resolvedDependencies;
          in {
            resolvedDependencies = res.resolvedDependencies // resolvedDeps;
            flake = res.flake // (foldl' (acc: key: acc // {${key}.${modName} = mod.outputs.${key};}) {} (attrNames mod.outputs));
          })
          {
            resolvedDependencies = {};
            inherit flake;
          } (attrNames flake.signalModules));
}
