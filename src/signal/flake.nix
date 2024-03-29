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
  dependencies.get = {
    flake,
    name,
  }:
    if !flake ? "inputs"
    then assert traceVerbose "flake.dependencies.get ${name} <not a flake>" true; {}
    else
      assert traceVerbose "flake.dependencies.get ${name} flake.inputs@{${toString (attrNames flake.inputs)}}" true;
      # for each signalModule "mod" in flake:
      #   res = dependency.set.merge res (module.toDependencies { inherit inputs; module = mod; })
      # return res
        foldl' (res: modName:
          assert traceVerbose "flake.dependencies.get(${name}).foldl' signalModules.${modName}" true;
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
    if !flake ? "inputs"
    then
      traceVerbose "flake.toDependencies ${name} <not a flake>" {
        ${name} = {
          input = flake;
          inherit outputs;
        };
      }
    else
      assert traceVerbose "flake.toDependencies ${name} flake.inputs@{${toString (attrNames flake.inputs)}}" true;
        dependency.set.merge (signal.flake.dependencies.get {inherit flake name;}) {
          ${name} = {
            input = flake;
            inherit outputs;
          };
        };
  set.toDependencies = {
    flakes,
    filter ? [],
    inputs ? flakes,
    outputs ? {},
  }:
    assert traceVerbose "flake.set.toDependencies flakes@{${toString (attrNames flakes)}} filter@[${toString (["self"] ++ filter)}]" true; let
      flakes' = removeAttrs flakes (["self"] ++ filter);
      inputs' = removeAttrs flakes ["self"];
      defaultOutputs = {
        homeManagerModules = ["default"];
        overlays = system: ["default" system];
      };
    in
      foldl' (res: name: let
        flake = flakes'.${name};
      in
        assert traceVerbose "flake.set.toDependencies().foldl' ${name}" true;
          dependency.set.merge res (signal.flake.toDependencies {
            # inputs = inputs';
            inherit flake name;
            outputs = outputs.${name} or defaultOutputs;
          })) {} (attrNames flakes');
  resolved.nixpkgs = {
    nixpkgs,
    flake',
    signalModuleName,
    crossSystem,
    allowUnfree,
    localSystem ? builtins.currentSystem or crossSystem,
    selfOverlays ? set.select (flake'.overlays or {}) ["default" crossSystem signalModuleName],
    exportedOverlays ? monad.resolve (flake'.exports.${signalModuleName}.overlays or []) crossSystem,
  }:
    import nixpkgs {
      inherit localSystem;
      inherit crossSystem;
      config.allowUnfree = allowUnfree;
      overlays = exportedOverlays ++ selfOverlays;
    };
  resolved.stdlib = {nixpkgs'}: nixpkgs'.lib.extend (final: prev: {signal = self.lib;});
  resolved.exports = {
    flake',
    crossSystem,
  }:
  # Result: {
  #   ${module} = {
  #     ${key} = monad.resolve export crossSystem;
  #   };
  # }
    mapAttrs (
      module: outputs:
        mapAttrs (
          key: export:
            monad.resolve export crossSystem
        )
        outputs
    )
    flake'.exports;
  resolve = {
    flake,
    # the name of the signalModule to resolve
    module,
    name ? module,
  }:
    assert traceVerbose "flake.resolve ${name} flake.inputs@{${toString (attrNames flake.inputs)}}" true; let
      flakeDeps = assert traceVerbose "flake.resolve(${name}).flakeDeps" true; signal.flake.dependencies.get {inherit flake name;};
      flakeRes = assert traceVerbose "flake.resolve(${name}).flakeRes" true;
        signal.flake.resolve' {
          inherit flake name;
          dependencies = flakeDeps;
        };
      flake' = traceVerbose "flake.resolve(${name}).flake'" flakeRes.flake;
      resDeps = traceVerbose "flake.resolve(${name}).resDeps" flakeRes.resolvedDependencies;
      exports =
        traceVerbose "flake.resolve(${name}).exports"
        (
          foldl'
          (acc: depName: set.mConcat acc resDeps.${depName}.outputs)
          (flake'.exports.${module} or flake'.exports."default" or {})
          (attrNames flakeDeps)
        );
    in
      std.recursiveUpdate flake' {
        exports.${module} =
          traceVerbose "flake.resolve(${name}) exports.${module}@{${toString (attrNames exports)})}"
          exports;
      };
  resolve' = {
    dependencies,
    flake,
    name ? "<unknown>",
  }:
    assert traceVerbose "flake.resolve' ${name} dependencies@{${toString (attrNames dependencies)}}" true;
      foldl' (res: modName: let
        modRes = module.resolve' {
          dependencies = dependencies // res.resolvedDependencies;
          module = flake.signalModules.${modName};
          name = "${name}.${modName}";
        };
        mod = modRes.module;
        resolvedDeps = modRes.resolvedDependencies;
      in
        assert traceVerbose "flake.resolve'(${name}).foldl' ${name}.signalModules.${modName}" true; {
          resolvedDependencies = res.resolvedDependencies // resolvedDeps;
          flake = res.flake // (foldl' (acc: key: acc // {${key}.${modName} = mod.outputs.${key};}) {} (attrNames mod.outputs));
        })
      {
        resolvedDependencies = {};
        inherit flake;
      } (attrNames (flake.signalModules or {}));
}
