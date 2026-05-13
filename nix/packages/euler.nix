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
  clang-tools,
  cmake,
  cmake-language-server,
  ...
}: let
  deps = [
    ripgrep
    fd
    coreutils
    rsync
    emacs-lsp-booster
    clang-tools
    cmake
    cmake-language-server
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
