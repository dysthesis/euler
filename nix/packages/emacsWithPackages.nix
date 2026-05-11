{
  emacsWithPackagesFromUsePackage,
  emacs-unstable-pgtk,
  cfg,
}:
emacsWithPackagesFromUsePackage {
  package = emacs-unstable-pgtk;
  config = "${cfg}/init.el";
}
