{
  emacsWithPackagesFromUsePackage,
  emacs,
  cfg,
  extraEmacsPackages ? (_: []),
  scopeOverride ? (_: _: {}),
}:
emacsWithPackagesFromUsePackage {
  package = emacs;
  config = "${cfg}/init.el";
  override = scopeOverride;
  extraEmacsPackages = epkgs:
    (with epkgs; [
      nerd-icons
      treesit-grammars.with-all-grammars
    ])
    ++ extraEmacsPackages epkgs;
}
