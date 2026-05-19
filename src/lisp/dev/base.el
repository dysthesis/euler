;;; -*- lexical-binding: t; -*-
(require 'core/lib)

;; Project management
(use-package project
  :config
  (add-to-list 'project-vc-extra-root-markers "Cargo.toml")
  (when (>= emacs-major-version 30)
    (setopt project-mode-line t))) ; show project name in modeline

(use-package markdown-mode
  :ensure t
  :hook ((markdown-mode . visual-line-mode)))

(use-package yaml-mode
  :ensure t
  :defer t)

(use-package json-mode
  :ensure t
  :defer t)

(defcustom euler-tool-programs
  '("emacs-lsp-booster"
    "ls"
    "gls"
    "rsync"
    "clangd"
    "clang-format"
    "cmake"
    "cmake-language-server"
    "rust-analyzer"
    "nil"
    "alejandra"
    "zls"
    "prettier"
    "shfmt"
    "codelldb")
  "External tools whose startup directories should survive local env updates."
  :type '(repeat string)
  :group 'euler)

(defun euler/tool-bin-directories (&optional programs)
  "Return executable directories for PROGRAMS without duplicates."
  (delete-dups
   (delq nil
         (mapcar (lambda (program)
                   (let ((path (executable-find program)))
                     (when path
		       (directory-file-name (file-name-directory path)))))
                 (or programs euler-tool-programs)))))

(defvar euler-tool-bin-directories (euler/tool-bin-directories)
  "Tool directories from Euler's startup PATH to preserve in local envs.")

(defun euler/prepend-to-local-path (directories)
  "Prepend DIRECTORIES to buffer-local PATH and `exec-path'."
  (let (merged)
    (dolist (dir (append directories
                         (split-string (or (getenv "PATH") "") path-separator t)))
      (when (and (stringp dir)
                 (not (euler/string-empty-p dir))
                 (not (member dir merged)))
        (push dir merged)))
    (setq merged (nreverse merged))
    (setenv "PATH" (euler/string-join merged path-separator))
    (setq-local exec-path (append merged (and (memq nil exec-path) '(nil))))))
;; Load direnv environments from .envrc
(use-package envrc
  :ensure t
  :defer 1
  :config
  (defun euler/envrc-preserve-tool-paths (buffer result)
    "Keep Euler-provided tools discoverable after envrc updates BUFFER."
    (with-current-buffer buffer
      (when (and (listp result)
                 euler-tool-bin-directories)
        (euler/prepend-to-local-path euler-tool-bin-directories))))

  (advice-add 'envrc--apply :after #'euler/envrc-preserve-tool-paths)
  (envrc-global-mode))

(provide 'dev/base)
