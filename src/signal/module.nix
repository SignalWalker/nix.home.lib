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
in {
  dependencies.collect = {
    inputs, # { flakeInput }
    module, # signalModule
  }:
  # -> { dependency }
    assert traceVerbose "module.dependencies.collect ${module.name}" true;
      foldl' (res: depName: let
        dep = module.dependencies.${depName};
      in
        dependency.set.merge res (signal.flake.toDependencies {
          inherit inputs;
          flake = dep.input;
          outputs = dep.outputs;
          name = depName;
        }))
      module.dependencies (attrNames module.dependencies);
  resolve' = {
    dependencies,
    module,
    name,
  }:
    assert traceVerbose "module.resolve' ${name}" true; let
      resolvedDeps = foldl' (res: depName: let
        dep = res.${depName};
      in
        if dep.__resolved or (!(module.dependencies ? ${depName}))
        then res
        else
          (res
            // (dependency.resolve' {
              dependencies = res;
              name = depName;
            })))
      dependencies (attrNames dependencies);
      modResDeps = set.filter (key: dep: dep.__resolved or false) resolvedDeps;
    in {
      resolvedDependencies = modResDeps;
      module = {
        inherit (module) name dependencies;
        outputs = module.outputs (mapAttrs (key: dep: dep.input) modResDeps);
      };
    };
}
