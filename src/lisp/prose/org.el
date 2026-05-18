;;; -*- lexical-binding: t; -*-
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Org-mode
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun euler/org-flyspell-mode-maybe ()
  "Enable Flyspell in Org when an ispell-compatible program exists."
  (when (executable-find (if (boundp 'ispell-program-name)
                             ispell-program-name
                           "ispell"))
    (flyspell-mode 1)))

(use-package org
  :hook ((org-mode . visual-line-mode)  ; wrap lines at word breaks
         (org-mode . euler/org-flyspell-mode-maybe))
  :config
  (setq org-directory "~/Documents/Org"
	org-agenda-files '("inbox.org" "tasks.org")))

(use-package org-modern
  :ensure t
  :after (org)
  :config
  (setq
   ;; Edit settings
   org-auto-align-tags nil
   org-tags-column 0
   org-catch-invisible-edits 'show-and-error
   org-special-ctrl-a/e t
   org-insert-heading-respect-content t
   
   ;; Org styling, hide markup etc.
   org-hide-emphasis-markers t
   org-modern-star 'replace
   org-pretty-entities t
   org-agenda-tags-column 0
   org-ellipsis " ↪")
  ;; Instead of just two states (TODO, DONE) we set up a few different states
  ;; that a task can be in. Run
  ;;     M-x describe-variable RET org-todo-keywords RET
  ;; for documentation on how these keywords work.
  (setq org-todo-keywords
        '((sequence "TODO(t)" "WAITING(w@/!)" "STARTED(s!)" "|" "DONE(d!)" "OBSOLETE(o@)"))
        org-modern-todo-faces
        '(("TODO" :foreground "#000000" :background "#ffaa88" :weight bold)
          ("WAITING" :foreground "#000000" :background "#abab77" :weight bold)
          ("STARTED" :foreground "#000000" :background "#7788aa" :weight bold)
          ("DONE" :foreground "#555555" :background "#080808" :weight bold)
          ("OBSOLETE" :foreground "#555555" :background "#080808" :weight bold :strike-through t)))
  (with-eval-after-load 'org (global-org-modern-mode))) 

;; centre text for writing
(use-package olivetti
  :ensure t
  :config
  (defun dysthesis/org-mode-setup ()
    "Enable prose-focused display tweaks for Org buffers."
    (org-indent-mode)
    (olivetti-mode)
    (display-line-numbers-mode 0)
    (olivetti-set-width 90))
  (add-hook 'org-mode-hook 'dysthesis/org-mode-setup))

(provide 'prose/org)
