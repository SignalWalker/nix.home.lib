with builtins; rec {
  listFiles' = dir: let
    entries = readDir dir;
  in (filter (name: entries.${name} != "directory") (attrNames entries));
  listFiles = dir: map (name: dir + "/${name}") (listFiles' dir);
  fileExtension = path: let
    ext = match "^.+\\.([^.]+)$" path;
  in
    if ext != null
    then head ext
    else null;
  fileName' = path: ext: replaceStrings [".${ext}"] [""] (baseNameOf path);
  fileName = path: let
    ext = fileExtension path;
  in
    if ext != null
    then fileName' path ext
    else baseNameOf path;
  fileParts = path: let
    ext = fileExtension path;
    dir = dirOf path;
  in
    (
      if ext != null
      then {
        name = fileName' path ext;
        inherit ext;
      }
      else {
        name = baseNameOf path;
      }
    )
    // (
      if dir != ""
      then {
        inherit dir;
      }
      else {}
    );
  listNix' = dir: filter (file: file ? ext && file.ext == "nix") (map fileParts (listFiles' dir));
  listNix = dir: map (file: dir + "/${file.name}.nix") (listNix' dir);
}
