{
  emacsWithPackages,
  cfg,
  makeWrapper,
  symlinkJoin,
  ...
}:
symlinkJoin {
  name = "euler";
  paths = [emacsWithPackages];
  buildInputs = [makeWrapper];
  postBuild = ''
    wrapProgram $out/bin/emacs \
      --add-flags "--init-directory=${cfg}"
  '';
  meta.mainProgram = "emacs";
}
