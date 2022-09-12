{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  setl = self.lib.set;
in {
  intersects = first: second: (std.intersectLists first second) != [];
}
