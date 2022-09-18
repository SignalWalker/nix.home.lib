# dependency: {
#   input: flakeInput
#   outputs: { ([name] | fn(system) -> [name]) }
# }
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
  flake = signal.flake;
in {
  outputs.merge = first: second:
    first
    // (mapAttrs (key: sVal: let
      fVal = first.${key} or null;
    in
      if fVal == null
      then sVal
      else
        (
          if isFunction fVal || isFunction sVal
          then monad.concat fVal sVal
          else (fVal ++ sVal)
        ))
    second);
  merge = first: second: {
    input =
      if first.input.lastModified >= second.input.lastModified
      then first
      else second;
    outputs = dependency.outputs.merge first.outputs second.outputs;
  };
  set.merge = first: second:
  # assert traceVerbose "dependency.set.merge {${toString (attrNames first)}} {${toString (attrNames second)}}" true;
    first
    // (mapAttrs (key: sDep: let
      fDep = first.${key} or null;
    in
      if fDep == null
      then sDep
      else assert traceVerbose "dependency.set.merge [COLLISION]: ${key}" true; dependency.merge fDep sDep)
    second);
  resolve' = {
    dependencies,
    name,
  }:
    assert traceVerbose "dependency.resolve ${name}" true; let
      dep = dependencies.${name};
      inputRes = flake.resolve' {
        inherit dependencies name;
        flake = dep.input;
      };
      input = inputRes.flake;
      mapNames = key: names: set.selectUnique input.${key} names;
    in
      inputRes.resolvedDependencies
      // {
        ${name} = {
          __resolved = true;
          inherit input;
          outputs = foldl' (res: key:
            if !(input ? ${key})
            then res
            else
              res
              // {
                ${key} = let
                  names = dep.outputs.${key};
                in
                  if isFunction names
                  then (system: set.selectUnique input.${key} (names system))
                  else (set.selectUnique input.${key} names);
              }) {} (attrNames dep.outputs);
        };
      };
}
