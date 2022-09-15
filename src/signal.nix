# dependency Schema:
# {
#   input: either flakeInput null
#   outputs: { (either [outputName] (fn(systemName) -> [outputName])) } # ex. { homeManagerModules = [ "default" ]; overlays = system: [ "default" system ]; }
# }
# signalModule Schema:
# {
#   dependencies: { dependency }
#   outputs: fn({ flakeInput }) -> { any }
# }
# resolvedSignalModule Schema:
# {
#   dependencies: { dependency }
#   outputs: { any }
#   depOutputs: { (monad [ any ]) }
# }
inputs @ {
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
in {
  dependency = import ./signal/dependency.nix inputs;
  module = import ./signal/module.nix inputs;
  flake = import ./signal/flake.nix inputs;
}
