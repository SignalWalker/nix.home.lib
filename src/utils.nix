inputs @ {nixpkgs}:
with builtins; let
  std = nixpkgs.lib;
  attrIfSome = opt: attrs: std.optionalAttrs (opt != null) attrs;
  listIfSome = opt: list: std.optionals (opt != null) list;
  listFiles' = dir: let
    entries = readDir dir;
  in (filter (name: entries.${name} != "directory") (attrNames entries));
  # some = value: { hasVal = true; inherit value; };
  # none = value { hasVal = false; value = null; };
  filterMap = fn: vals:
    std.foldl
    (
      res: val: let
        fres = fn val;
      in
        if fres.isSome
        then (res ++ [fres.value])
        else res
    )
    []
    vals;
in rec {
  inherit
    attrIfSome
    listIfSome
    filterMap
    ;

  inherit listFiles';
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
  listFiles = dir: map (name: dir + "/${name}") (listFiles' dir);
  listNix' = dir: filter (file: file ? ext && file.ext == "nix") (map fileParts (listFiles' dir));
  listNix = dir: map (file: dir + "/${file.name}.nix") (listNix' dir);
  listNixNames = dir: map (file: file.name) (listNix' dir);

  mkOutputList' = let
    oldDefaults = {
      "overlays" = "overlay";
      "nixosModules" = "nixosModule";
      "packages" = "defaultPackage";
      "apps" = "defaultApp";
    };
  in
    output: keys: flake:
      (
        if (flake ? "${output}")
        then
          (std.foldl (acc: key:
            acc
            ++ (
              if flake.${output} ? "${key}"
              then [flake.${output}.${key}]
              else []
            )) []
          keys)
        else []
      )
      ++ (
        if ((oldDefaults ? "${output}") && (flake ? "${oldDefaults.${output}}") && (elem "default" keys))
        then [flake.${oldDefaults.${output}}]
        else []
      );
  mkOutputList = output: keys: flakes: concatLists (map (mkOutputList' output keys) flakes);
  mkOverlayList' = keys: flakes: mkOutputList "overlays" keys flakes;
  mkOverlayList = system: flakes: mkOverlayList' [system "default"] flakes;

  send-notification = {
    summary,
    body ? null,
    stack ? null,
    app ? null,
    category ? null,
    timeout ? null,
    notify-send ? "notify-send",
  }:
    concatStringsSep " " ([
        notify-send
      ]
      ++ (map ({
        var,
        val,
      }:
        val) (filter ({
        var,
        val,
      }:
        var != null) [
        {
          var = timeout;
          val = "-t ${timeout}";
        }
        {
          var = stack;
          val = "-h string:x-dunst-stack-tag:${stack}";
        }
        {
          var = category;
          val = "-c ${category}";
        }
        {
          var = app;
          val = "-a ${app}";
        }
      ]))
      ++ [
        summary
      ]
      ++ (listIfSome body [
        body
      ]));
}
