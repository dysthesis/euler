{
  pkgs,
  emacs,
  parsePackagesFromPackageRequires,
}: let
  sources = import ./npins;
  pinnedSources = builtins.removeAttrs sources ["__functor"];
  base = pkgs.emacsPackagesFor emacs;

  buildOne = epkgs: name: source: let
    imported = source {};
  in
    epkgs.trivialBuild rec {
      pname = name;
      version = imported.revision or "unstable";
      src = imported.outPath;
      packageRequires =
        builtins.readFile "${src}/${name}.el"
        |> parsePackagesFromPackageRequires
        |> builtins.map (x: epkgs.${x});
      meta.homepage =
        if imported ? repository
        then imported.repository.url or null
        else null;
    };

  # Expose this so emacsWithPackagesFromUsePackage can use it as `override`
  scopeOverride = final: _prev:
    builtins.mapAttrs (name: source: buildOne final name source) pinnedSources;
in {
  packages = base.overrideScope scopeOverride;
  inherit scopeOverride;
}
