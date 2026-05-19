;;; -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'tools/lsp)

(declare-function zig-mode "zig-mode")
(declare-function zig-ts-mode "zig-ts-mode")

(defun euler/zig-mode ()
  "Use `zig-ts-mode' when Zig grammar exists, otherwise use `zig-mode'."
  (interactive)
  (cond
   ((and (fboundp 'zig-ts-mode)
         (fboundp 'treesit-language-available-p)
         (treesit-language-available-p 'zig))
    (zig-ts-mode))
   ((fboundp 'zig-mode)
    (zig-mode))
   (t
    (fundamental-mode))))

(defun euler/zig-eglot-ensure-maybe ()
  "Start Eglot for Zig when `zls' is available."
  (when (executable-find "zls")
    (euler/eglot-set-server 'zig-ts-mode '("zls"))
    (euler/eglot-set-server 'zig-mode '("zls"))
    (euler/eglot-ensure-deferred)))

(add-to-list 'auto-mode-alist '("\\.zig\\'" . euler/zig-mode))

(use-package zig-ts-mode
  :ensure t
  :defer t
  :hook (zig-ts-mode-local-vars . euler/zig-eglot-ensure-maybe)
  :config
  ;; HACK: Rely on `major-mode-remap-defaults' instead (upstream also doesn't
  ;;   check if the grammars are ready before adding these entries, which will
  ;;   bork zig buffers).
  (cl-callf2 rassq-delete-all 'zig-ts-mode auto-mode-alist))

(use-package zig-mode
  :if (locate-library "zig-mode")
  :defer t
  :hook (zig-mode-local-vars . euler/zig-eglot-ensure-maybe)
  :config
  (setq zig-format-on-save nil)) ;; use apheleia

(provide 'lang/zig)
