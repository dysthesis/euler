{
  emacsWithPackagesFromUsePackage,
  emacs-unstable-pgtk, cfg,
}:
emacsWithPackagesFromUsePackage {
  package = emacs-unstable-pgtk;
  config = "${cfg}/init.el";
  extraEmacsPackages = epkgs: with epkgs; [
    nerd-icons
    treesit-grammars.with-all-grammars
  ];
}
