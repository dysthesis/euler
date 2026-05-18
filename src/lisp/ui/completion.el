;;; -*- lexical-binding: t; -*-
(use-package which-key
  :ensure t
  :config
  (which-key-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Minibuffer and completion
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Vertico: better vertical completion for minibuffer commands
(use-package vertico
  :ensure t
  :init
  ;; You'll want to make sure that e.g. fido-mode isn't enabled
  (vertico-mode))

(use-package vertico-directory
  :ensure nil
  :after vertico
  :bind (:map vertico-map
	      ("M-DEL" . vertico-directory-delete-word)))

;; Marginalia: annotations for minibuffer
(use-package marginalia
  :ensure t
  :config
  (marginalia-mode))

;; Orderless: powerful completion style
(use-package orderless
  :ensure t
  :config
  (setq completion-styles '(orderless)
	orderless-matching-styles '(orderless-literal     ;; the component is treated as a literal string that must occur in the candidate
				    orderless-prefixes    ;; the component is split at word endings and each piece must match at a word boundary in the candidate, occurring in that order
				    orderless-regexp      ;; the component is treated as a regexp that must match somewhere in the candidate
					    orderless-initialism  ;; each character of the component should appear as the beginning of a word in the candidate, in order
					    orderless-flex)))     ;; When all else fails, fuzzy-match.

(defcustom euler/completion-dabbrev-max-buffer-size (* 256 1024)
  "Maximum buffer size where automatic dabbrev completion is enabled."
  :type 'integer)

(defun euler/cape-dabbrev-small-buffer ()
  "Run `cape-dabbrev' only where automatic scans stay cheap."
  (unless (> (buffer-size) euler/completion-dabbrev-max-buffer-size)
    (cape-dabbrev)))

;; Corfu: Popup completion-at-point
(use-package corfu
  :ensure t
  :init
  (global-corfu-mode)
  :custom
  (corfu-auto t)
  (corfu-auto-prefix 1)          ;; I'm impatient; trigger completin faster.
  (corfu-cycle t)                ;; Enable cycling for `corfu-next/previous'
  (corfu-quit-at-boundary nil)   ;; Never quit at completion boundary
  (corfu-quit-no-match nil)      ;; Never quit, even if there is no match
  (corfu-preview-current nil)    ;; Disable current candidate preview
  (corfu-preselect 'prompt)      ;; Preselect the prompt
  (corfu-on-exact-match 'insert) ;; Configure handling of exact matches

  :bind
  (:map corfu-map
        ("SPC" . corfu-insert-separator)
        ("C-n" . corfu-next)
        ("C-p" . corfu-previous)))

;; Part of corfu
(use-package corfu-popupinfo
  :after corfu
  :ensure nil
  :hook (corfu-mode . corfu-popupinfo-mode)
  :custom
  (corfu-popupinfo-delay '(0.25 . 0.1))
  (corfu-popupinfo-hide nil)
  :config
  (corfu-popupinfo-mode))

;; Make corfu popup come up in terminal overlay
(use-package corfu-terminal
  :if (not (display-graphic-p))
  :ensure t
  :config
  (corfu-terminal-mode))

;; Fancy completion-at-point functions; there's too much in the cape package to
;; configure here; dive in when you're comfortable!
(use-package cape
  :ensure t
  :init
  (add-to-list 'completion-at-point-functions #'euler/cape-dabbrev-small-buffer)
  (add-to-list 'completion-at-point-functions #'cape-file))

;; Pretty icons for corfu
(use-package nerd-icons-corfu
  :ensure t
  :defer t
  :init
  (defun euler/corfu-enable-nerd-icons ()
    "Enable Corfu margin icons after startup."
    (when (require 'nerd-icons-corfu nil t)
      (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter)))
  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-idle-timer 2 nil #'euler/corfu-enable-nerd-icons))))

(use-package nerd-icons-completion
  :ensure t
  :defer t
  :init
  (defun euler/completion-enable-nerd-icons ()
    "Enable minibuffer completion icons after startup."
    (when (require 'nerd-icons-completion nil t)
      (nerd-icons-completion-mode)
      (when (bound-and-true-p marginalia-mode)
        (nerd-icons-completion-marginalia-setup))))
  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-idle-timer 2 nil
                                   #'euler/completion-enable-nerd-icons))))


(provide 'ui/completion)
