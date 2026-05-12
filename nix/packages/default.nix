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
      (register-extensions euler)
    '';
    elsaExtension = pkgs.writeTextDir "elsa-extension-euler.el" ''
      ;;; elsa-extension-euler.el --- Elsa adapters for Euler config -*- lexical-binding: t; -*-

      (require 'elsa-analyser)
      (require 'elsa-declare)
      (require 'elsa-types)

      (elsa-declare-defvar avy-dispatch-alist mixed)
      (elsa-declare-defvar avy-ring mixed)
      (elsa-declare-defvar custom-theme-load-path (list string))
      (elsa-declare-defvar euler--initial-gc-threshold int)
      (elsa-declare-defvar gc-cons-threshold int)
      (elsa-declare-defvar native-comp-eln-load-path (list string))

      (defun elsa-euler--analyse-setter-pairs (forms scope state)
        "Analyse value positions in setter-like FORMS."
        (while forms
          (when (cadr forms)
            (elsa--analyse-form (cadr forms) scope state))
          (setq forms (cddr forms))))

      (defun elsa-euler--analyse-use-package-custom (forms scope state)
        "Analyse value positions in use-package :custom FORMS."
        (dolist (form forms)
          (when (elsa-form-list-p form)
            (when-let ((value (elsa-cadr form)))
              (elsa--analyse-form value scope state)))))

      (defun elsa--analyse:setopt (form scope state)
        "Analyse `setopt' values without treating option names as variable reads."
        (elsa-euler--analyse-setter-pairs (elsa-cdr form) scope state)
        (oset form type (elsa-type-nil)))

      (defun elsa--analyse:boundp (form scope state)
        "Analyse `boundp' without Elsa's over-aggressive narrowing."
        (elsa--analyse-body (elsa-cdr form) scope state)
        (oset form type (elsa-make-type bool)))

      (defun elsa--analyse:deftheme (form _scope _state)
        "Treat `deftheme' arguments as declarative theme data."
        (oset form type (elsa-type-nil)))

      (defun elsa--analyse:custom-theme-set-faces (form _scope _state)
        "Treat `custom-theme-set-faces' arguments as declarative theme data."
        (oset form type (elsa-type-nil)))

      (defun elsa--analyse:custom-theme-set-variables (form _scope _state)
        "Treat `custom-theme-set-variables' arguments as declarative theme data."
        (oset form type (elsa-type-nil)))

      (defun elsa--analyse:general-create-definer (form _scope _state)
        "Treat `general-create-definer' arguments as declarative keybinding data."
        (oset form type (elsa-type-nil)))

      (defun elsa--analyse:use-package (form scope state)
        "Analyse executable parts of `use-package' and skip its DSL data."
        (let ((forms (elsa-nthcdr 2 form)))
          (while forms
            (let ((keyword (car forms))
                  (args nil))
              (setq forms (cdr forms))
              (while (and forms (not (elsa-form-keyword-p (car forms))))
                (push (car forms) args)
                (setq forms (cdr forms)))
              (setq args (nreverse args))
              (pcase (and (elsa-form-keyword-p keyword) (elsa-get-name keyword))
                ((or :preface :init :config)
                 (elsa--analyse-body args scope state))
                ((or :if :when :unless)
                 (elsa--analyse-body args scope state))
                (:custom
                 (elsa-euler--analyse-use-package-custom args scope state))))))
        (oset form type (elsa-type-nil)))

      (provide 'elsa-extension-euler)
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
          -L ${elsaExtension} \
          -L src \
          -L src/themes \
          --eval "(setq ansi-inhibit-ansi t)" \
          --eval "(setq native-comp-jit-compilation nil)" \
          --eval "(setq native-comp-async-report-warnings-errors 'silent)" \
          --load=elsa \
          --funcall=elsa-run \
          -with-exit \
          src/early-init.el \
          src/init.el \
          src/themes/noir-theme.el \
          > $out/report.txt 2>&1
      '';
    };
  };
}
