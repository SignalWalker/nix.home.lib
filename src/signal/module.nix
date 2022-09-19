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
          # inherit inputs;
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
      depDiv = set.divide (key: val: val.__resolved or false) dependencies;
      resDeps = depDiv.inner;
      unresDeps = depDiv.outer;
      modResDeps = foldl' (res: depName: let
        dep = dependencies.${depName};
      in
        if dep.__resolved or false
        then (assert traceVerbose "module.resolve'(${name}) ${depName} already resolved" true; res)
        else if (!(module.dependencies ? ${depName}))
        then assert traceVerbose "module.resolve'(${name}) ${depName} not required" true; res
        else
          (res
            // (dependency.resolve' {
              dependencies = dependencies // res;
              name = depName;
            })))
      {} (attrNames dependencies);
    in {
      resolvedDependencies = modResDeps;
      module = {
        inherit (module) name dependencies;
        outputs = module.outputs (mapAttrs (key: dep: dep.input) (resDeps // modResDeps));
      };
    };
}
