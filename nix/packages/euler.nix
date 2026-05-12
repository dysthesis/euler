{
  emacsWithPackages,
  cfg,
  makeWrapper,
  symlinkJoin,
  lib,
  ripgrep,
  fd,
  emacs-lsp-booster,
  ...
}:
let
  deps = [
    ripgrep
    fd
    emacs-lsp-booster
  ];
in symlinkJoin {
  name = "euler";
  paths = [emacsWithPackages];
  buildInputs = [makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/emacs \
      --add-flags "--init-directory=${cfg}" \
      --prefix PATH ":" "${lib.makeBinPath deps}"

  '';
  meta.mainProgram = "emacs";
}
