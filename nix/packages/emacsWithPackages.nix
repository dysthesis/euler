{
  emacsWithPackagesFromUsePackage,
  emacs,
  cfg,
}:
emacsWithPackagesFromUsePackage {
  package = emacs;
  config = "${cfg}/init.el";
  extraEmacsPackages = epkgs:
    with epkgs; [
      nerd-icons
      treesit-grammars.with-all-grammars
    ];
}
