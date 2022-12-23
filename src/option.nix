{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  option = self.lib.option;
in {
  unwrapOr = opt: def:
    if opt == null
    then def
    else opt;
}
