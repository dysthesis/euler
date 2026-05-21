;;; -*- lexical-binding: t; -*-
(declare-function euler/expensive-visual-buffer-p "core/settings" (&optional size))

(use-package which-key
  :ensure t
  :defer 1
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
  :demand t
  :config
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
  :defer 1
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
  :type 'integer
  :group 'euler)

(defun euler/completion-expensive-buffer-p (&optional size)
  "Return non-nil when automatic completion work should be reduced."
  (or (file-remote-p default-directory)
      (if (fboundp 'euler/expensive-visual-buffer-p)
          (euler/expensive-visual-buffer-p size)
        (> (buffer-size) (or size (* 1024 1024))))))

(defun euler/cape-dabbrev-small-buffer ()
  "Run `cape-dabbrev' only where automatic scans stay cheap."
  (unless (euler/completion-expensive-buffer-p
           euler/completion-dabbrev-max-buffer-size)
    (cape-dabbrev)))

(defun euler/corfu-adjust-for-buffer ()
  "Reduce automatic Corfu work in buffers where typing latency matters more."
  (when (euler/completion-expensive-buffer-p)
    (setq-local corfu-auto nil)))

;; Corfu: Popup completion-at-point
(use-package corfu
  :ensure t
  :demand t
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.08)
  (corfu-auto-prefix 2)          ;; Keep auto completion without first-char churn.
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
        ("C-p" . corfu-previous))
  :hook (corfu-mode . euler/corfu-adjust-for-buffer)
  :config
  (global-corfu-mode))

;; Part of corfu
(use-package corfu-popupinfo
  :after corfu
  :ensure nil
  :hook (corfu-mode . corfu-popupinfo-mode)
  :custom
  (corfu-popupinfo-delay '(0.25 . 0.1))
  (corfu-popupinfo-hide nil))

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
