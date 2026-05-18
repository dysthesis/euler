;;; -*- lexical-binding: t; -*-
(require 'tools/lsp)
(require 'ui/keys)

(euler/eglot-set-server
 '((rustic-mode :language-id "rust")
   rust-mode
   rust-ts-mode)
 '("rust-analyzer"))

(use-package rust-mode
  :ensure t
  :defer t
  :init
  (setq rust-mode-treesitter-derive t
        rust-indent-method-chain t))

(add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-ts-mode))
(add-hook 'rust-mode-hook #'euler/eglot-ensure-deferred)
(add-hook 'rust-ts-mode-hook #'euler/eglot-ensure-deferred)

(defun euler/rust-cargo-audit ()
  "Run cargo audit for the current Rust project."
  (interactive)
  (require 'rustic-cargo)
  (rustic-run-cargo-command `(,(rustic-cargo-bin) "audit")
                            (list :clippy-fix t
                                  :mode 'rustic-cargo-custom-command-mode)))

(use-package rustic
  :ensure t
  :commands (rustic-mode
             rustic-cargo-build
             rustic-cargo-bench
             rustic-cargo-check
             rustic-cargo-clippy
             rustic-cargo-build-doc
             rustic-cargo-doc
             rustic-cargo-fmt
             rustic-cargo-new
             rustic-cargo-outdated
             rustic-cargo-run
             rustic-cargo-test
             rustic-cargo-current-test)
  :hook (rustic-mode . euler/eglot-ensure-deferred)
  :init
  (setq rustic-babel-format-src-block nil
        rustic-load-optional-libraries nil
        rustic-format-trigger nil
        rustic-lsp-client 'eglot
        rustic-lsp-setup-p nil)
  (dysthesis/start/leader-keys
    :keymaps '(rust-ts-mode-map rust-mode-map rustic-mode-map)
    "m b" '(:ignore t :wk "Build")
    "m b a" '(euler/rust-cargo-audit :wk "Cargo audit")
    "m b b" '(rustic-cargo-build :wk "Cargo build")
    "m b B" '(rustic-cargo-bench :wk "Cargo bench")
    "m b c" '(rustic-cargo-check :wk "Cargo check")
    "m b C" '(rustic-cargo-clippy :wk "Cargo clippy")
    "m b d" '(rustic-cargo-build-doc :wk "Cargo doc")
    "m b D" '(rustic-cargo-doc :wk "Cargo doc --open")
    "m b f" '(rustic-cargo-fmt :wk "Cargo fmt")
    "m b n" '(rustic-cargo-new :wk "Cargo new")
    "m b o" '(rustic-cargo-outdated :wk "Cargo outdated")
    "m b r" '(rustic-cargo-run :wk "Cargo run")
    "m t" '(:ignore t :wk "Cargo test")
    "m t a" '(rustic-cargo-test :wk "All")
    "m t t" '(rustic-cargo-current-test :wk "Current test"))
  :config
  (with-eval-after-load 'org-src
    (autoload 'org-babel-execute:rustic "rustic-babel")
    (defalias 'org-babel-execute:rust #'org-babel-execute:rustic)
    (add-to-list 'org-src-lang-modes '("rust" . rustic)))

  (add-to-list 'display-buffer-alist
	       '("\\`\\*\\(rustic-compilation\\|cargo-run\\)"
                 (display-buffer-reuse-window display-buffer-at-bottom)
                 (window-height . 0.25)))

  )

(provide 'lang/rust)
