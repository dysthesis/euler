{
  pkgs,
  emacs,
}: let
  sources = import ./npins;

  base = pkgs.emacsPackagesFor emacs;
in
  base.overrideScope'
  (
    final: prev:
      builtins.mapAttrs
      (name: source: let
        source' = import source {};
      in
        final.trivialBuild {
          pname = name;
          version = source'.revision or "unstable";

          src = source'.outPath;

          packageRequires = [];

          meta = {
            homepage =
              if source' ? repository
              then source'.repository.url or null
              else null;
          };
        })
      sources
  )
