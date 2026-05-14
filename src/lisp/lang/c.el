;;; -*- lexical-binding: t; -*-
(require 'core/lib)
(require 'tools/lsp)

(defvar euler/cc-default-include-paths '("include" "includes")
  "Relative include directories to expose to `find-file-at-point'.")

(defvar euler/cc-default-header-file-mode 'c-mode
  "Fallback major mode for C-family header files.")

(defun euler/cc--file-exists-any-p (&rest files)
  "Return non-nil when any path in FILES exists."
  (catch 'found
    (dolist (file files)
      (when (and file (file-exists-p file))
        (throw 'found t)))))

(defun euler/cc--re-search-for (regexp)
  "Return non-nil when REGEXP matches near the start of the current buffer."
  (save-excursion
    (save-restriction
      (save-match-data
        (widen)
        (goto-char (point-min))
        (re-search-forward
         regexp
         (and (boundp 'magic-mode-regexp-match-limit)
	      magic-mode-regexp-match-limit)
         t)))))

(defun euler/cc-c-c++-mode ()
  "Use C or C++ mode for header files."
  (let* ((file (buffer-file-name (buffer-base-buffer)))
         (base (and file (file-name-sans-extension file)))
         (mode
          (cond
           ((and base
                 (euler/cc--file-exists-any-p
                  (concat base ".cc")
                  (concat base ".cpp")
                  (concat base ".cxx")))
            'c++-mode)
           ((and base
                 (euler/cc--file-exists-any-p
                  (concat base ".c")))
            'c-mode)
           ((euler/cc--re-search-for
             (let ((id "[A-Za-z_][A-Za-z0-9_]*")
                   (ws "[ \t\r]+")
                   (ws? "[ \t\r]*"))
	       (concat "^" ws? "\\(?:"
		       "using" ws "\\(?:namespace" ws "std;\\|std::\\)"
		       "\\|namespace\\(?:" ws id "\\)?" ws? "{"
		       "\\|class" ws id ws? "[:{\n]"
		       "\\|template" ws? "<.*>"
		       "\\|#include" ws? "<\\(?:algorithm\\|array\\|iostream\\|map\\|memory\\|string\\|utility\\|vector\\)>"
		       "\\)")))
            'c++-mode)
           (t euler/cc-default-header-file-mode)))
         (remapped (or (alist-get mode major-mode-remap-alist nil nil #'eq)
		       mode)))
    (funcall remapped)))

(defun euler/cc-resolve-include-paths ()
  "Return include directories near the current project."
  (let ((path (or buffer-file-name default-directory))
        paths)
    (dolist (dir euler/cc-default-include-paths (nreverse paths))
      (push
       (if (file-name-absolute-p dir)
           dir
         (let ((root (locate-dominating-file path dir)))
           (when root
             (expand-file-name dir root))))
       paths))
    (delq nil paths)))

(defun euler/cc-init-ffap-integration ()
  "Teach `find-file-at-point' about nearby C/C++ include directories."
  (when (project-current nil)
    (require 'ffap)
    (make-local-variable 'ffap-c-path)
    (make-local-variable 'ffap-c++-path)
    (dolist (dir (euler/cc-resolve-include-paths))
      (pcase major-mode
        ((or 'c-mode 'c-ts-mode)
         (add-to-list 'ffap-c-path (expand-file-name dir)))
        ((or 'c++-mode 'c++-ts-mode)
         (add-to-list 'ffap-c++-path (expand-file-name dir)))))))

(defun euler/cc-c++-lineup-inclass (langelem)
  "Indent in-class C++ lines one level past access labels."
  (and (eq major-mode 'c++-mode)
       (or (assoc 'access-label c-syntactic-context)
           (save-excursion
             (save-match-data
	       (re-search-backward
                "\\(?:p\\(?:ublic\\|r\\(?:otected\\|ivate\\)\\)\\)"
                (c-langelem-pos langelem)
                t))))
       '++))

(defun euler/cc-lineup-arglist-close (langelem)
  "Line up closing arglist delimiters after an opener, comma, or semicolon."
  (when (save-excursion
          (save-match-data
            (skip-chars-backward " \t\n" (c-langelem-pos langelem))
            (memq (char-before) (list ?, ?\( ?\;))))
    (c-lineup-arglist langelem)))

(defun euler/cc--ignore-c-after-change-errors (fn &rest args)
  "Ignore cc-mode parser errors from simultaneous edits."
  (ignore-errors (apply fn args)))

(defun euler/cc-set-style ()
  "Use the Euler C indentation style in classic cc-mode buffers."
  (c-set-style "euler"))

(use-package cc-mode
  :ensure nil
  :mode ("\\.h\\'" . euler/cc-c-c++-mode)
  :hook
  ((c-mode-local-vars . euler/cc-init-ffap-integration)
   (c-ts-mode-local-vars . euler/cc-init-ffap-integration)
   (c++-mode-local-vars . euler/cc-init-ffap-integration)
   (c++-ts-mode-local-vars . euler/cc-init-ffap-integration)
   (c-mode-local-vars . eglot-ensure)
   (c-ts-mode-local-vars . eglot-ensure)
   (c++-mode-local-vars . eglot-ensure)
   (c++-ts-mode-local-vars . eglot-ensure)
   (c-mode-common . euler/cc-set-style))
  :init
  (with-eval-after-load 'ffap
    (add-to-list 'ffap-alist '(c-mode . ffap-c-mode))
    (add-to-list 'ffap-alist '(c-ts-mode . ffap-c-mode))
    (add-to-list 'ffap-alist '(c++-ts-mode . ffap-c++-mode)))
  :config
  (dolist (mode '(c-mode c++-mode c-or-c++-mode))
    (setq major-mode-remap-defaults
          (delete (list mode) major-mode-remap-defaults)))

  (with-eval-after-load 'find-file
    (add-to-list 'find-sibling-rules
                 '("/\\([^/]+\\)\\.\\(?:c\\|cc\\|cpp\\|cxx\\)\\'"
                   "\\1.\\(?:h\\|hh\\|hpp\\|hxx\\)\\'"))
    (add-to-list 'find-sibling-rules
                 '("/\\([^/]+\\)\\.\\(?:h\\|hh\\|hpp\\|hxx\\)\\'"
                   "\\1.\\(?:c\\|cc\\|cpp\\|cxx\\)\\'")))

  (when (fboundp 'c-after-change-mark-abnormal-strings)
    (advice-add 'c-after-change-mark-abnormal-strings
                :around #'euler/cc--ignore-c-after-change-errors))

  (setq c-basic-offset tab-width
        c-backspace-function #'delete-backward-char)

  (with-eval-after-load 'c-ts-mode
    (setq c-ts-mode-indent-offset tab-width
          c-ts-mode-indent-style 'linux))

  (c-add-style
   "euler"
   '((c-comment-only-line-offset . 0)
     (c-hanging-braces-alist (brace-list-open)
                             (brace-entry-open)
                             (substatement-open after)
                             (block-close . c-snug-do-while)
                             (arglist-cont-nonempty))
     (c-cleanup-list brace-else-brace)
     (c-offsets-alist
      (knr-argdecl-intro . 0)
      (substatement-open . 0)
      (substatement-label . 0)
      (statement-cont . +)
      (case-label . +)
      (brace-list-intro . 0)
      (brace-list-close . -)
      (arglist-intro . +)
      (arglist-close euler/cc-lineup-arglist-close 0)
      (inline-open . 0)
      (inlambda . 0)
      (access-label . -)
      (inclass euler/cc-c++-lineup-inclass +)
      (label . 0)))))

(use-package cmake-mode
  :ensure t
  :mode (("CMakeLists\\.txt\\'" . cmake-mode)
         ("\\.cmake\\'" . cmake-mode))
  :hook
  ((cmake-mode . eglot-ensure)
   (cmake-ts-mode . eglot-ensure)))

;; Sometimes you need to tell Eglot where to find the language server.
(dolist (mode '(c-mode c-ts-mode c++-mode c++-ts-mode))
  (euler/eglot-set-server
   mode `("clangd" ,(format "-j=%d" (max 1 (/ (num-processors) 2))))))

(provide 'lang/c)
