;;; -*- lexical-binding: t; -*-
(require 'tools/lsp)

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook (nix-mode . euler/eglot-ensure-deferred))

(use-package nix-ts-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook (nix-ts-mode . euler/eglot-ensure-deferred))

(euler/eglot-set-server '(nix-mode nix-ts-mode) '("nil"))

(provide 'lang/nix)
