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
      (elsa-declare-defvar apheleia-formatter mixed)
      (elsa-declare-defvar apheleia-formatters mixed)
      (elsa-declare-defvar apheleia-formatters-mode-extension-assoc mixed)
      (elsa-declare-defvar apheleia-formatters-respect-indent-level mixed)
      (elsa-declare-defvar apheleia-global-mode bool)
      (elsa-declare-defvar apheleia-inhibit mixed)
      (elsa-declare-defvar apheleia-mode bool)
      (elsa-declare-defvar c-default-style mixed)
      (elsa-declare-defvar c-syntactic-context mixed)
      (elsa-declare-defvar custom-theme-load-path (list string))
      (elsa-declare-defvar dired-actual-switches mixed)
      (elsa-declare-defvar dired-auto-revert-buffer mixed)
      (elsa-declare-defvar dired-clean-confirm-killing-deleted-buffers bool)
      (elsa-declare-defvar dired-create-destination-dirs mixed)
      (elsa-declare-defvar dired-dwim-target bool)
      (elsa-declare-defvar dired-guess-shell-alist-user mixed)
      (elsa-declare-defvar dired-listing-switches string)
      (elsa-declare-defvar dired-mode-map mixed)
      (elsa-declare-defvar dired-omit-files string)
      (elsa-declare-defvar dired-omit-verbose bool)
      (elsa-declare-defvar dired-recursive-copies mixed)
      (elsa-declare-defvar dired-recursive-deletes mixed)
      (elsa-declare-defvar dired-use-ls-dired bool)
      (elsa-declare-defvar dired-vc-rename-file bool)
      (elsa-declare-defvar dirvish-attributes mixed)
      (elsa-declare-defvar dirvish-cache-dir mixed)
      (elsa-declare-defvar dirvish-header-line-height mixed)
      (elsa-declare-defvar dirvish-hide-cursor mixed)
      (elsa-declare-defvar dirvish-hide-details mixed)
      (elsa-declare-defvar dirvish-mode-line-format mixed)
      (elsa-declare-defvar dirvish-mode-line-height mixed)
      (elsa-declare-defvar dirvish-mode-map mixed)
      (elsa-declare-defvar dirvish-reuse-session mixed)
      (elsa-declare-defvar dirvish-subtree-always-show-state bool)
      (elsa-declare-defvar dirvish-use-header-line bool)
      (elsa-declare-defvar dirvish-use-mode-line bool)
      (elsa-declare-defvar eglot-auto-display-help-buffer bool)
      (elsa-declare-defvar eglot-autoshutdown bool)
      (elsa-declare-defvar eglot-booster-io-only bool)
      (elsa-declare-defvar eglot-code-action-indications mixed)
      (elsa-declare-defvar eglot-events-buffer-config mixed)
      (elsa-declare-defvar eglot-mode-map mixed)
      (elsa-declare-defvar eglot-stay-out-of mixed)
      (elsa-declare-defvar eglot-sync-connect mixed)
      (elsa-declare-defvar eglot--managed-mode bool)
      (elsa-declare-defvar eglot-current-linepos-function mixed)
      (elsa-declare-defvar eglot-move-to-linepos-function mixed)
      (elsa-declare-defvar evil-collection-magit-rebase-commands-w-descriptions mixed)
      (elsa-declare-defvar evil-collection-magit-section-use-z-for-folds bool)
      (elsa-declare-defvar evil-collection-magit-state mixed)
      (elsa-declare-defvar evil-collection-magit-use-z-for-folds bool)
      (elsa-declare-defvar evil-local-mode bool)
      (elsa-declare-defvar evil-state symbol)
      (elsa-declare-defvar evil-visual-selection symbol)
      (elsa-declare-defvar euler/format-on-save-disabled-modes mixed)
      (elsa-declare-defvar euler/format-with mixed)
      (elsa-declare-defvar euler/format-with-eglot-mode bool)
      (elsa-declare-defvar euler/format-with-eglot-mode-map mixed)
      (elsa-declare-defvar euler--initial-gc-threshold int)
      (elsa-declare-defvar forge-add-default-bindings bool)
      (elsa-declare-defvar forge-bug-reference-remote-files bool)
      (elsa-declare-defvar forge-database-file mixed)
      (elsa-declare-defvar forge-topics-mode-map mixed)
      (elsa-declare-defvar gc-cons-threshold int)
      (elsa-declare-defvar ghub-graphql-message-progress bool)
      (elsa-declare-defvar git-commit-mode bool)
      (elsa-declare-defvar git-commit-style-convention-checks mixed)
      (elsa-declare-defvar git-commit-summary-max-length int)
      (elsa-declare-defvar git-rebase-mode-map mixed)
      (elsa-declare-defvar image-dired-db-file mixed)
      (elsa-declare-defvar image-dired-dir mixed)
      (elsa-declare-defvar image-dired-gallery-dir mixed)
      (elsa-declare-defvar image-dired-temp-image-file mixed)
      (elsa-declare-defvar image-dired-temp-rotate-image-file mixed)
      (elsa-declare-defvar image-dired-thumb-size int)
      (elsa-declare-defvar insert-directory-program string)
      (elsa-declare-defvar json-array-type mixed)
      (elsa-declare-defvar json-false mixed)
      (elsa-declare-defvar json-key-type mixed)
      (elsa-declare-defvar json-object-type mixed)
      (elsa-declare-defvar left-fringe-width int)
      (elsa-declare-defvar long-line-threshold mixed)
      (elsa-declare-defvar ls-lisp-use-insert-directory-program bool)
      (elsa-declare-defvar magit--default-directory string)
      (elsa-declare-defvar magit-auto-revert-mode bool)
      (elsa-declare-defvar magit-branch-section-map mixed)
      (elsa-declare-defvar magit-bury-buffer-function mixed)
      (elsa-declare-defvar magit-diff-mode-map mixed)
      (elsa-declare-defvar magit-diff-refine-hunk mixed)
      (elsa-declare-defvar magit-diff-visit-file-hook mixed)
      (elsa-declare-defvar magit-display-buffer-function mixed)
      (elsa-declare-defvar magit-display-buffer-noselect bool)
      (elsa-declare-defvar magit-git-executable mixed)
      (elsa-declare-defvar magit-mode-map mixed)
      (elsa-declare-defvar magit-post-refresh-hook mixed)
      (elsa-declare-defvar magit-pre-refresh-hook mixed)
      (elsa-declare-defvar magit-process-mode-hook mixed)
      (elsa-declare-defvar magit-process-mode-map mixed)
      (elsa-declare-defvar magit-remote-section-map mixed)
      (elsa-declare-defvar magit-revision-insert-related-refs bool)
      (elsa-declare-defvar magit-revision-mode-map mixed)
      (elsa-declare-defvar magit-save-repository-buffers bool)
      (elsa-declare-defvar magit-section-mode-hook mixed)
      (elsa-declare-defvar magit-section-mode-map mixed)
      (elsa-declare-defvar magit-stash-mode-map mixed)
      (elsa-declare-defvar magit-status-mode-hook mixed)
      (elsa-declare-defvar magit-status-mode-map mixed)
      (elsa-declare-defvar magit-uniquify-buffer-names mixed)
      (elsa-declare-defvar native-comp-eln-load-path (list string))
      (elsa-declare-defvar revert-buffer-function mixed)
      (elsa-declare-defvar right-fringe-width int)
      (elsa-declare-defvar transient-default-level int)
      (elsa-declare-defvar transient-display-buffer-action mixed)
      (elsa-declare-defvar transient-history-file mixed)
      (elsa-declare-defvar transient-levels-file mixed)
      (elsa-declare-defvar transient-map mixed)
      (elsa-declare-defvar transient-show-during-minibuffer-read bool)
      (elsa-declare-defvar transient-values-file mixed)
      (elsa-declare-defvar wdired-mode-map mixed)

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

      (defun elsa--analyse:defface (form _scope _state)
        "Treat `defface' arguments as declarative face data."
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

      (defun elsa--analyse:declare-function (form _scope _state)
        "Treat `declare-function' as compile-time declaration data."
        (oset form type (elsa-type-nil)))

      (defun elsa--analyse:with-selected-window (form scope state)
        "Analyse `with-selected-window' body without macro type noise."
        (when-let ((window (elsa-cadr form)))
          (elsa--analyse-form window scope state))
        (elsa--analyse-body (elsa-nthcdr 2 form) scope state)
        (oset form type (elsa-type-nil)))

      (defun elsa--analyse:with-current-buffer (form scope state)
        "Analyse `with-current-buffer' body without macro type noise."
        (when-let ((buffer (elsa-cadr form)))
          (elsa--analyse-form buffer scope state))
        (elsa--analyse-body (elsa-nthcdr 2 form) scope state)
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
        find -L "$out" \
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
