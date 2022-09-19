{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  set = self.lib.set;
  monad = self.lib.monad;
in {
  select = set: names: foldl' (acc: name: acc ++ (std.optional (set ? ${name}) set.${name})) [] names;
  selectFrom = sets: names: foldl' (acc: s: acc ++ (set.select s names)) [] sets;
  selectMapUnique = mapFn: set: names:
    (foldl' (acc: name:
        if !(elem name acc.keys)
        then {
          keys = acc.keys ++ [name];
          values = acc.values ++ (std.optional (set ? ${name}) (mapFn name set.${name}));
        }
        else acc) {
        keys = [];
        values = [];
      }
      names)
    .values;
  selectUnique = s: names: set.selectMapUnique (key: val: val) s names;
  merge = mergeFn: first: second: first // (mapAttrs (key: val: mergeFn key first val) second);
  concatMap = mapFn: first: second: set.merge (key: f: sval: (first.${key} or []) ++ (mapFn key sval)) first second;
  concat = first: second: set.concatMap (key: val: val) first second;
  append = first: second: set.concatMap (key: val: [val]) first second;
  mConcat = first: second:
    set.merge (key: f: sval: let
      fval = first.${key} or [];
    in
      if isFunction fval || isFunction sval
      then (monad.concat fval sval)
      else fval ++ sval)
    first
    second;
  divideMap = filterFn: mapFn: s:
    foldl' (res: key: let
      filterIn = filterFn key s.${key};
    in {
      inner =
        if filterIn
        then res.inner // {${key} = mapFn key s.${key};}
        else res.inner;
      outer =
        if !filterIn
        then res.outer // {${key} = s.${key};}
        else res.outer;
    }) {
      inner = {};
      outer = {};
    } (attrNames s);
  divide = filterFn: s: set.divideMap filterFn (key: val: val) s;
  # Filter entries from a set which don't pass a filtering function.
  filterMap = filterFn: mapFn: s: (set.divideMap filterFn mapFn s).inner;
  filter = filterFn: s: set.filterMap filterFn (key: val: val) s;
  # Return a set with only the keys present in both first and second. Values are taken from second.
  intersect = first: second: set.filter (key: val: first ? ${key}) second;
}
