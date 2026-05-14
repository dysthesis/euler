;;; -*- lexical-binding: t; -*-
(require 'tools/lsp)

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook (nix-mode . eglot-ensure))

(use-package nix-ts-mode
  :ensure t
  :mode "\\.nix\\'")

(euler/eglot-set-server 'nix-mode '("nil"))

(provide 'lang/nix)
