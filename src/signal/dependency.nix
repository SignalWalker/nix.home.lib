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
  default.base = {
    input = null;
    outputs.homeManagerModules = ["default"];
    outputs.overlays = system: ["default" system];
    outputs.signalModules = ["default"];
  };
  default.new = input: dlib.default.base // {inherit input;};
  default.fromInputs = {
    inputs,
    filter ? [],
  }: let
    filter' = filter ++ ["self" "nixpkgs"];
  in
    foldl' (acc: inputName: let
      input = inputs.${inputName};
    in
      if elem inputName filter'
      then acc
      else acc // {${inputName} = dlib.default.new input;}) {} (attrNames inputs);
  input.choose = first: second:
    if (second == null) || ((first != null) && (first.lastModified >= second.lastModified))
    then first
    else second;
  # fn(fn(...) -> ..., dependency, dependency) -> dependency
  merge' = outputMapFn: first: second:
    assert (traceVerbose "dependency.merge'" true); {
      input = dlib.input.choose (first.input or null) (second.input or null);
      outputs = dlib.outputs.mergeSets' outputMapFn first.outputs second.outputs;
    };
  merge = dlib.merge' std.id;
  # fn({dependency}, {dependency}) -> {dependency}
  mergeSets = first: second:
    assert (traceVerbose "dependency.mergeSets" true);
      first
      // (mapAttrs (key: sDep:
        if first ? ${key}
        then dlib.merge first.${key} sDep
        else sDep)
      second);
  outputs.merge' = mapFn: first: second:
    if isFunction first || isFunction second
    then (system: mapFn (monad.concat first second system))
    else (mapFn (first ++ second));
  outputs.merge = dlib.outputs.merge' std.id;
  outputs.mergeSets' = mapFn: first: second:
    assert (std.traceSeq ["dependency.outputs.mergeSets'" first second] true);
    assert isAttrs first;
    assert isAttrs second;
      first
      // (mapAttrs (key: sOut: let
        fOut = first.${key} or [];
      in
        dlib.outputs.merge' mapFn fOut sOut)
      second);
  outputs.mergeSets = first: second: assert traceVerbose "dependency.outputs.mergeSets { ${toString (attrNames first)} } { ${toString (attrNames second)} }" true; dlib.outputs.mergeSets' (std.id) first second;
  # fn(dependency) -> { either [any] (fn(systemName) -> [any]) }
  outputs.collect' = deps: depName: let
    dep = deps.${depName};
    input = dep.input;
    outputs = dep.outputs;
  in
    assert dlib.isDep dep;
    assert (traceVerbose "dependency.outputs.collect' ${depName} { ${toString (attrNames deps)} }" true); let
      result' = mapAttrs (key: outMon:
        assert traceVerbose "dependency.outputs.collect'.result'. ${depName}.${key} ${
          if isFunction outMon
          then "<LAMBDA>"
          else "[${toString outMon}]"
        }"
        true;
          if (isFunction outMon)
          then (system: set.select (input.${key} or {}) (outMon system))
          else set.select (input.${key} or {}) outMon)
      outputs;
    in
      assert traceVerbose "dependency.outputs.collect'.foldl'" (foldl' (res: name: let val = result'.${name}; in res && (isList val || (name != "signalModules" && isFunction val))) true (attrNames result'));
        # "for every signalModule in result', merge that module's outputs into result'"
        foldl' (res: mod: let
          depOutputs = mlib.outputs.collect' {
            dependencies = removeAttrs deps [ depName ];
            module = mod;
          };
        in
          assert traceVerbose "dependency.outputs.collect'.foldl'." true;
            dlib.outputs.mergeSets res depOutputs) (removeAttrs result' ["signalModules"]) (result'.signalModules or []);
  # fn({ dependency }) -> { either [any] (fn(systemName) -> [any]) }
  outputs.collect = deps:
    assert traceVerbose "dependency.outputs.collect" true;
      foldl' (acc: depName: let dep = deps.${depName}; in dlib.outputs.mergeSets acc (dlib.outputs.collect' deps depName)) {} (attrNames deps);
  # fn({ flakeInput }, dependencyName, dependency) -> { dependency }
  resolve' = inputs: depName: dep':
    assert (std.traceSeq ["dependency.resolve'" "{<inputs>}" depName (removeAttrs dep' ["input"])] true);
    assert dlib.isDep dep'; let
      dep = dep';
      input =
        if (dep.input or null) == null
        then inputs.${depName}
        else dep.input;
      signalModules = std.intersectLists (attrNames (input.signalModules or {})) (dep.outputs.signalModules or []);
      resBase = {${depName} = dep // {inherit input;};};
    in
      if (signalModules != [])
      then (foldl' (res: modName: assert (traceVerbose "dependency.resolve'.fold <RES> '${modName}'" true); dlib.mergeSets res (dlib.resolve inputs input.signalModules.${modName}.dependencies)) resBase signalModules)
      else resBase;
  isDep = dep: (dep ? input -> (isAttrs dep.input || dep.input == null)) && (isAttrs dep.outputs && (foldl' (res: output: res && (isList output || isFunction output)) true (attrValues dep.outputs)));
  # fn({ flakeInput }, { dependency }) -> { dependency }
  resolve = inputs: deps:
    assert !(inputs ? "self");
    assert (traceVerbose "dependency.resolve inputs@{ ${toString (attrNames inputs)} } deps@{ ${toString (attrNames deps)} }" true);
      foldl' (acc: depName: let
        dep = deps.${depName};
      in
        dlib.mergeSets acc (dlib.resolve' inputs depName dep)) {} (attrNames deps);
}
