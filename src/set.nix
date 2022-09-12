{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  set = self.lib.set;
in {
  select = set: names: foldl' (acc: name: acc ++ (std.optional (set ? ${name}) set.${name})) [] names;
  selectFrom = sets: names: foldl' (acc: s: acc ++ (set.select s names)) [] sets;
  merge = mergeFn: first: second: first // (mapAttrs (key: val: mergeFn first second.${key} key) second);
  append = first: second: set.merge (key: f: sval: (f.${key} or []) ++ [sval]) first second;
  concat = first: second: set.merge (key: f: sval: (f.${key} or []) ++ sval) first second;
}
