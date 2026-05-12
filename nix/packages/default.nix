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
  in {
    legacyPackages = {
      inherit emacsPackages;
    };

    packages = rec {
      # Emacs wrapped with whatever packages it needs
      emacsWithPackages = pkgs.callPackage ./emacsWithPackages.nix {
        inherit
          emacs
          ;
        cfg = cfgSource;
      };

      # Config directory, native-compiled after package discovery to avoid a cycle.
      cfg = pkgs.runCommand "euler-cfg" {nativeBuildInputs = [emacsWithPackages];} ''
        cp -r ${cfgSource} $out
        chmod -R u+w $out
        mkdir -p "$out/share/emacs/native-lisp"

        ${lib.optionalString (emacs.withNativeCompilation or false) ''
          find "$out" -type f -name '*.el' -not -name '.dir-locals.el' \
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

      # Emacs with packages and config
      euler = pkgs.callPackage ./euler.nix {inherit emacsWithPackages cfg lib;};

      # Emacs packages that I use that are not in emacs-overlay or nixpkgs.
      inherit (emacsPackages) eglot-booster;

      default = euler;
    };
  };
}
