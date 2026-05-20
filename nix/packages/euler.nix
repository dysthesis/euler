{
  emacsWithPackages,
  cfg,
  makeWrapper,
  symlinkJoin,
  lib,
  ripgrep,
  fd,
  coreutils,
  rsync,
  emacs-lsp-booster,
  perl,
  vscode-extensions,
  ...
}: let
  deps = [
    ripgrep
    fd
    coreutils
    rsync
    emacs-lsp-booster
    perl
    vscode-extensions.vadimcn.vscode-lldb.adapter
  ];
in
  symlinkJoin {
    name = "euler";
    paths = [emacsWithPackages];
    buildInputs = [makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/emacs \
        --add-flags "--init-directory=${cfg}" \
        --prefix EMACSNATIVELOADPATH : "${emacsWithPackages.deps}/share/emacs/native-lisp" \
        --prefix EMACSNATIVELOADPATH : "${cfg}/share/emacs/native-lisp" \
        --prefix PATH ":" "${lib.makeBinPath deps}"
    '';
    meta.mainProgram = "emacs";
  }
