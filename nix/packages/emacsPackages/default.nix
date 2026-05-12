{
  pkgs,
  emacs,
}: let
  sources = import ./npins;
  base = pkgs.emacsPackagesFor emacs;

  # Build a source from npins into an Emacs package.
  buildOne = pkgs: name: source: let
    imported = import source {};
  in
    pkgs.trivialBuild {
      pname = name;
      version = imported.revision or "unstable";
      src = imported.outPath;
      packageRequires = [];
      meta = {
        homepage =
          if imported ? repository
          then imported.repository.url or null
          else null;
      };
    };
in
  # Map the builder into all the sources
  base.overrideScope'
  (
    final: prev:
      builtins.mapAttrs
      (name: source: buildOne final name source)
      sources
  )
