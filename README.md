# Nix SignalModules Library

## SignalModules

```nix
dependencySet = {
    inputs = {}; # set of flakeInputs from which to resolve dependencies
    filter = []; # names of attributes to remove from `inputs` (ex. "self")
    outputs = {
        ${inputName}.${output} = []; # names of attributes depended on from `${inputName}.${output}`
    };
};
resolvedDependency = {}; # a flake input resolved
signalModule.${foo} = {
    dependencies = dependencySet;
    outputs =
        dependencies: # resolved dependencies, as specified in `dependencies` above
        {
            # attribute set of flake outputs
        };
};
```
