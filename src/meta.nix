{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  lib = self.lib;
  meta = lib.meta;
in {
  deprecated = {
    name,
    new,
    reason ? "",
  }: val:
    trace "${msg}${
      if reason != ""
      then " (${reason}})"
      else ""
    } deprecated; use ${new} instead"
    val;
}
