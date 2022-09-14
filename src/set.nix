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
  # Filter entries from a set which don't pass a filtering function.
  filterMap = filterFn: mapFn: s:
    foldl' (acc: key: let
      res = {
        keep = filterFn key s.${key};
        value = mapFn key s.${key};
      };
    in
      if res.keep
      then acc // {${key} = res.value;}
      else acc) {} (attrNames s);
  filter = filterFn: s: set.filterMap filterFn (key: val: val) s;
  # Return a set with only the keys present in both first and second. Values are taken from second.
  intersect = first: second: set.filter (key: val: first ? ${key}) second;
}
