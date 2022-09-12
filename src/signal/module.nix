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
  dlib = signal.dependency;
  mlib = signal.module;
in {
  isUnresolved = module: isAttrs module.dependencies && isFunction module.outputs && !(module ? depOutputs);
  # fn({ dependency }, signalModule) -> resolvedSignalModule
  resolve' = {
    dependencies,
    module,
    name ? module.name,
  }:
    assert traceVerbose "module.resolve' ${name}" true;
    assert isAttrs dependencies;
    assert mlib.isUnresolved module; {
      inherit dependencies;
      name = "${name}'";
      outputs = module.outputs dependencies;
      depOutputs = dlib.outputs.collect dependencies;
    };
  # fn({ flakeInput }, signalModule) -> resolvedSignalModule
  resolve = {
    inputs,
    module,
    name ? module.name,
  }:
    assert traceVerbose "module.resolve ${name}" true;
      mlib.resolve' {
        dependencies = dlib.resolve inputs module.dependencies;
        inherit module name;
      };
  outputs.collect' = {
    dependencies,
    module,
    name ? module.name,
  }:
    assert traceVerbose "module.outputs.collect' ${name}" true;
      mlib.outputs.collect {
        module = mlib.resolve' {inherit dependencies module name;};
        inherit name;
      };
  outputs.collect = {
    module,
    name ? module.name,
  }:
    assert traceVerbose "module.outputs.collect ${name}" true;
      dlib.outputs.mergeSets (mapAttrs (key: output:
        if isFunction output
        then (system: [(output system)])
        else (attrValues output))
      module.outputs)
      module.depOutputs;
}
