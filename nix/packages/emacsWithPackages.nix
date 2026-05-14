{
  emacsWithPackagesFromUsePackage,
  emacs,
  cfg,
  lib,
  extraEmacsPackages ? (_: []),
  scopeOverride ? (_: _: {}),
}: let
  cfgSource = ../../src;
  elispFiles =
    lib.filesystem.listFilesRecursive cfgSource
    |> builtins.filter (path: lib.hasSuffix ".el" (toString path))
    |> builtins.sort (a: b: (toString a) < (toString b));
  usePackageConfig = lib.concatMapStringsSep "\n" builtins.readFile elispFiles;
in
  emacsWithPackagesFromUsePackage {
    package = emacs;
    config = usePackageConfig;
    override = scopeOverride;
    extraEmacsPackages = epkgs:
      (with epkgs; [
        nerd-icons
        treesit-grammars.with-all-grammars
      ])
      ++ extraEmacsPackages epkgs;
  }
