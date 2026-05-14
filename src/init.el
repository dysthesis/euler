;;; -*- lexical-binding: t; -*-
;;; Guardrail

(when (< emacs-major-version 29)
  (error "Euler only works with Emacs 29 and newer; you have version %s"
	 emacs-major-version))

(let ((lisp-dir (expand-file-name "lisp" (file-name-directory
					  (or load-file-name
					      buffer-file-name)))))
  (add-to-list 'load-path lisp-dir))

(require 'core/lib)
(require 'core/settings)
(require 'dev/base)
(require 'dev/fold)
(require 'lang/c)
(require 'lang/nix)
(require 'lang/rust)
(require 'lang/zig)
(require 'tools/debug)
(require 'tools/files)
(require 'tools/format)
(require 'tools/lsp)
(require 'tools/templates)
(require 'tools/vc)
(require 'ui/base)
(require 'ui/completion)
(require 'ui/keys)
(require 'ui/mode-line)
(require 'ui/navigation)
(require 'prose/org)
