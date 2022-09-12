{
  self,
  nixpkgs,
  ...
}:
with builtins; let
  std = nixpkgs.lib;
  lib = self.lib;
  fsl = lib.fs;
in {
  dir.fromPathSimple = path: fsl.dir.fromPathFilter {dir = path;};
  dir.fromPathFilter = args @ {
    path,
    filterFn ? (name: type: true),
  }: let
    entries = readDir path;
  in
    foldl' (acc: name: let
      type = entries.${name};
    in
      if name == "__type"
      then throw "file name collision: '__type'"
      else if type == "unknown" || !(filterFn name type)
      then acc
      else
        acc
        // {
          ${name} = lib.enum.match type {
            "symlink" = throw "unimplemented";
            "unknown" = throw "unreachable";
            "regular" = fsl.file.fromPath "${path}/${name}";
            "directory" = fsl.dir.fromPathFilter (args // {path = "${path}/${name}";});
            __default = throw "unrecognized file type: ${type}";
          };
        }) {__type = "directory";} (attrNames entries);
  dir.fromPath = arg:
    if isAttrs arg
    then fsl.dir.fromPathFilter arg
    else (assert isString arg; fsl.dir.fromPathSimple arg);
  path.listDirContents = path: let
    entries = readDir path;
  in
    map (name: {
      inherit name;
      type = entries.${name};
    }) (attrNames entries);
  path.filterContents = {
    path,
    filterFn,
  }:
    filter filterFn (fsl.path.listDirContents path);
  path.mapContents = {
    path,
    mapFn,
  }:
    map mapFn (fsl.path.listDirContents path);
  path.filterMapContents = {
    path,
    fn,
  }:
    foldl' (res: entry: let
      val = fn entry.name entry.type;
    in
      if val.keep
      then res ++ [val.value]
      else res) [] (fsl.path.listDirContents path);
  path.listFileNames = path: fsl.path.filterMapContents { inherit path; fn = name: type: { keep = type == "regular"; value = name; }; };
  path.listFilePaths = path:
    fsl.path.filterMapContents {
      inherit path;
      fn = name: type: {
        keep = type == "regular";
        value = "${path}/${name}";
      };
    };
  path.listFiles = path:
    fsl.path.filterMapContents {
      inherit path;
      fn = name: type: {
        keep = type == "regular";
        value = fsl.file.fromPathParts {
          path = "${path}/${name}";
          fullName = name;
          dir = path;
        };
      };
    };
  path.listFilePathsWithExt = {
    path,
    ext,
  }:
    fsl.path.filterMapContents {
      inherit path;
      fn = name: type: {
        keep = type == "regular" && (fsl.path.ext name == ext);
        value = "${path}/${name}";
      };
    };
  path.listNix = path:
    fsl.path.listFilePathsWithExt {
      inherit path;
      ext = "nix";
    };
  path.listNixFiles = path:
    map (filePath:
      fsl.file.fromPathParts {
        path = filePath;
        dir = path;
        ext = "nix";
      }) (fsl.path.listNix path);
  file.fromPathSimple = path: fsl.file.fromParts {inherit path;};
  file.fromPathParts = {
    path,
    ext ? fsl.path.ext name,
    fullName ? baseNameOf path,
    name ?
      if ext != null
      then fsl.file.name {inherit path ext;}
      else fullName,
    dir ? dirOf path,
  }: let
    result =
      {
        inherit path name fullName;
      }
      // (
        if dir != ""
        then {inherit dir;}
        else {}
      )
      // (
        if ext != null
        then {inherit ext;}
        else {}
      );
  in
    result // {__type = "file";};
  file.fromPath = arg:
    if isAttrs arg
    then fsl.file.fromPathParts arg
    else (assert isString arg; fsl.file.fromPathSimple arg);
  path.dir = builtins.dirOf;
  path.ext = path: let
    ext = match "^.+\\.([^.]+)$" path;
  in
    if ext != null
    then head ext
    else null;
  path.nameSimple = path: fsl.path.nameFromParts {inherit path;};
  path.nameFromParts = {
    path,
    ext ? fsl.file.ext path,
  }:
    if ext != null
    then (replaceStrings [".${ext}"] [""] (baseNameOf path))
    else (baseNameOf path);
  path.name = arg:
    if isAttrs arg
    then fsl.path.nameFromParts arg
    else (assert isString arg; fsl.path.nameSimple arg);
  path.toFile = fsl.file.fromPathSimple;
}
