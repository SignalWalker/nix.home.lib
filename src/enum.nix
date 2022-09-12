{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.std;
  lib = self.lib;
  enuml = lib.enum;
in {
  match = value: expressions: expressions.${value} or expressions.__default or throw "unmatched enum '${value}' from { ${toString (attrNames expressions)} }";
}
