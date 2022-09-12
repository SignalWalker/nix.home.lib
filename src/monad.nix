{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  monad = self.lib.monad;
in {
  # monad: either any (fn(any) -> any)
  resolve = mon: args:
    if isFunction mon
    then mon args
    else mon;
  apply = fn: mon: args: fn (monad.resolve mon args);
  concat = first: second: args: (monad.resolve first args) ++ (monad.resolve second args);
  update = first: second: args: (monad.resolve first args) // (monad.resolve second args);
  fold = fn: nul: monads: args: foldl' (acc: mon: fn acc (monad.resolve mon args)) nul monads;
}
