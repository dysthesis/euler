;;; -*- lexical-binding: t; -*-
(use-package zig-ts-mode
  :ensure t
  :defer t
  :config
  (setq major-mode-remap-alist
	'((yaml-mode . yaml-ts-mode)))
  ;; HACK: Rely on `major-mode-remap-defaults' instead (upstream also doesn't
  ;;   check if the grammars are ready before adding these entries, which will
  ;;   bork zig buffers).
  (cl-callf2 rassq-delete-all 'zig-ts-mode auto-mode-alist))

(use-package zig-mode
  :defer t
  :config
  (setq zig-format-on-save nil)) ;; use apheleia

(provide 'lang/zig)
