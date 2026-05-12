{
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    emacs = pkgs.emacs-unstable-pgtk;

    emacsPackages = import ./emacsPackages {
      inherit pkgs emacs;
    };
    cfgSource = pkgs.callPackage ./cfg.nix {};

    mkEmacsWithPackages = extraEmacsPackages:
      pkgs.callPackage ./emacsWithPackages.nix {
        inherit emacs extraEmacsPackages;
        cfg = cfgSource;
      };

    emacsWithPackages = mkEmacsWithPackages (_: []);
    emacsWithElsa = mkEmacsWithPackages (epkgs: [epkgs.elsa]);
    elsafile = pkgs.writeText "Elsafile.el" ''
      ;; Elsa loads its default ruleset automatically; this file opts the project in.
    '';

    cfg = pkgs.runCommand "euler-cfg" {nativeBuildInputs = [emacsWithPackages];} ''
      cp -r ${cfgSource} $out
      chmod -R u+w $out
      mkdir -p "$out/share/emacs/native-lisp"

      ${lib.optionalString (emacs.withNativeCompilation or false) ''
        find -L "$out" "${emacsWithPackages.deps}/share/emacs/site-lisp" \
          -type f -name '*.el' -not -name '.dir-locals.el' \
          -exec emacs --batch \
            -f package-activate-all \
            --eval "(setq native-comp-eln-load-path '(\"$out/share/emacs/native-lisp\"))" \
            --eval "(setq native-comp-async-report-warnings-errors 'silent)" \
            --eval "(setq byte-compile-error-on-warn nil)" \
            --eval "(add-to-list 'load-path \"$out\")" \
            --eval "(add-to-list 'custom-theme-load-path \"$out/themes\")" \
            --eval "(require 'use-package)" \
            -f batch-native-compile {} +
      ''}
    '';
  in {
    legacyPackages = {
      inherit emacsPackages;
    };

    packages = rec {
      # Emacs wrapped with whatever packages it needs
      inherit emacsWithPackages emacsWithElsa cfg;

      # Emacs with packages and config
      euler = pkgs.callPackage ./euler.nix {inherit emacsWithPackages cfg lib;};

      # Emacs packages that I use that are not in emacs-overlay or nixpkgs.
      inherit (emacsPackages) eglot-booster;

      default = euler;
    };

    checks = {
      elsa = pkgs.runCommand "euler-elsa-report" {nativeBuildInputs = [emacsWithElsa];} ''
        export HOME="$TMPDIR/home"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        export XDG_CONFIG_HOME="$TMPDIR/config"
        export XDG_STATE_HOME="$TMPDIR/state"
        export EMACSNATIVELOADPATH="$TMPDIR/eln-cache"
        mkdir -p "$HOME" "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$EMACSNATIVELOADPATH"

        cp ${elsafile} Elsafile.el
        cp -r ${cfgSource} src
        chmod -R u+w src

        mkdir -p $out

        emacs --batch --no-init-file --no-splash \
          -f package-activate-all \
          -L src \
          -L src/themes \
          --eval "(setq ansi-inhibit-ansi t)" \
          --eval "(setq native-comp-jit-compilation nil)" \
          --eval "(setq native-comp-async-report-warnings-errors 'silent)" \
          --load=elsa \
          --funcall=elsa-run \
          src/early-init.el \
          src/init.el \
          src/themes/noir-theme.el \
          > $out/report.txt 2>&1
      '';
    };
  };
}
