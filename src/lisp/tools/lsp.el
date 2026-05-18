;;; -*- lexical-binding: t; -*-
(require 'core/lib)
(require 'ui/keys)

(defgroup euler/lsp nil
  "Euler LSP integration."
  :group 'tools)

(defcustom euler/lsp-defer-shutdown 3
  "Seconds to defer Eglot server shutdown after its last buffer is closed.
If nil or 0, shut servers down immediately."
  :type '(choice (const :tag "Disabled" nil)
                 (const :tag "No delay" 0)
                 (number :tag "Delay seconds"))
  :group 'euler/lsp)

(defvar euler/lsp--default-read-process-output-max
  (default-value 'read-process-output-max)
  "Saved `read-process-output-max' before LSP optimisation.")

(defvar euler/lsp--default-gc-cons-threshold gc-cons-threshold
  "Saved `gc-cons-threshold' before LSP optimisation.")

(defvar euler/lsp--optimisation-init-p nil
  "Non-nil when LSP optimisation defaults have been saved.")

(defvar euler/lsp--deferred-shutdown-timers (make-hash-table)
  "Deferred Eglot shutdown timers by server.")

(defvar euler/lsp-optimisation-mode-map (make-sparse-keymap)
  "Keymap for `euler/lsp-optimisation-mode'.")

(define-minor-mode euler/lsp-optimisation-mode
  "Apply global GC and process I/O tuning while LSP servers are active."
  :group 'euler/lsp
  :global t
  :init-value nil
  (if euler/lsp-optimisation-mode
      (progn
        (setq-default read-process-output-max (* 4 1024 1024))
        (unless (fboundp 'igc-info)
          (setq gc-cons-threshold (* 64 1024 1024))))
    (setq-default read-process-output-max
                  euler/lsp--default-read-process-output-max)
    (unless (fboundp 'igc-info)
      (setq gc-cons-threshold euler/lsp--default-gc-cons-threshold))))

(defun euler/lsp--managed-buffer-p (buffer)
  "Return non-nil when BUFFER is currently managed by Eglot."
  (and (bufferp buffer)
       (with-current-buffer buffer
         (bound-and-true-p eglot--managed-mode))))

(defun euler/lsp-disable-optimisation-maybe ()
  "Disable LSP optimisation if no live Eglot buffers remain."
  (unless (euler/some #'euler/lsp--managed-buffer-p (buffer-list))
    (euler/lsp-optimisation-mode -1)))

(defun euler/lsp-sync-optimisation-mode ()
  "Enable or disable LSP optimisation according to Eglot buffer state."
  (if (bound-and-true-p eglot--managed-mode)
      (euler/lsp-optimisation-mode 1)
    (euler/lsp-disable-optimisation-maybe)))

(defun euler/lsp--cancel-deferred-shutdown (server)
  "Cancel any deferred shutdown timer for SERVER."
  (let ((timer (gethash server euler/lsp--deferred-shutdown-timers)))
    (when timer
      (when (timerp timer)
        (cancel-timer timer))
      (remhash server euler/lsp--deferred-shutdown-timers))))

(defun euler/lsp--shutdown-eglot-server-if-idle (shutdown server)
  "Run SHUTDOWN for SERVER if it still has no managed buffers."
  (remhash server euler/lsp--deferred-shutdown-timers)
  (unless (eglot--managed-buffers server)
    (funcall shutdown server)
    (euler/lsp-disable-optimisation-maybe)))

(defun euler/lsp--defer-eglot-shutdown (shutdown server)
  "Defer SHUTDOWN for SERVER according to `euler/lsp-defer-shutdown'."
  (euler/lsp--cancel-deferred-shutdown server)
  (if (or (null euler/lsp-defer-shutdown)
          (equal euler/lsp-defer-shutdown 0))
      (prog1 (funcall shutdown server)
        (euler/lsp-disable-optimisation-maybe))
    (puthash
     server
     (run-at-time
      (if (numberp euler/lsp-defer-shutdown)
          euler/lsp-defer-shutdown
        3)
      nil #'euler/lsp--shutdown-eglot-server-if-idle shutdown server)
     euler/lsp--deferred-shutdown-timers)))

(defun euler/lsp-defer-eglot-shutdown-a (fn &rest args)
  "Around advice for FN to defer Eglot auto-shutdown."
  (let ((shutdown (symbol-function 'eglot-shutdown)))
    (unwind-protect
        (progn
          (fset 'eglot-shutdown
                (lambda (&optional server)
                  (if server
		      (euler/lsp--defer-eglot-shutdown shutdown server)
                    (funcall shutdown server))))
          (apply fn args))
      (fset 'eglot-shutdown shutdown))))

(defun euler/eglot-set-server (mode &rest alternatives)
  "Set ALTERNATIVES as the Eglot server for MODE.
MODE and ALTERNATIVES follow `eglot-server-programs'."
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs
                 (cons mode
		       (if (cdr alternatives)
                           (eglot-alternatives alternatives)
                         (car alternatives))))))

(defvar euler/eglot--help-buffer nil
  "Reusable help buffer for Eglot hover documentation.")

(defun euler/eglot-lookup-documentation ()
  "Show Eglot hover documentation for the thing at point."
  (interactive)
  (require 'eglot)
  (let* ((hover (jsonrpc-request (eglot--current-server-or-lose)
                                 :textDocument/hover
                                 (eglot--TextDocumentPositionParams)))
         (contents (and hover (plist-get hover :contents)))
         (range (and hover (plist-get hover :range))))
    (let ((blurb (and contents
		      (not (euler/sequence-empty-p contents))
		      (eglot--hover-info contents range)))
          (hint (thing-at-point 'symbol t)))
      (if blurb
          (with-current-buffer
	      (or (and (buffer-live-p euler/eglot--help-buffer)
		       euler/eglot--help-buffer)
                  (setq euler/eglot--help-buffer
                        (generate-new-buffer "*eglot-help*")))
            (with-help-window (current-buffer)
	      (rename-buffer
	       (format "*eglot-help%s*"
		       (if hint (format " for %s" hint) ""))
	       t)
	      (with-current-buffer standard-output
                (insert blurb)
                (setq-local nobreak-char-display nil))))
        (display-local-help)))))

(use-package eglot
  :commands (eglot
             eglot-ensure
             eglot-rename
             eglot-code-actions)
  :init
  (setq eglot-sync-connect 1
        eglot-autoshutdown t
        eglot-send-changes-idle-time 0.1
        eglot-extend-to-xref t
        eglot-stay-out-of
        (cons 'company
	      (remq 'company
                    (ensure-list (and (boundp 'eglot-stay-out-of)
				      eglot-stay-out-of)))))
  (dysthesis/start/leader-keys
    "c" '(:ignore t :which-key "Code")
    "c <escape>" '(keyboard-escape-quit :which-key t)
    "c r" '(eglot-rename :which-key "Rename")
    "c a" '(eglot-code-actions :which-key "Actions")
    "c h" '(euler/eglot-lookup-documentation :which-key "Docs"))
  :config
  (when (boundp 'eglot-auto-display-help-buffer)
    (setq eglot-auto-display-help-buffer nil))
  (when (boundp 'eglot-code-action-indications)
    (setq eglot-code-action-indications '(eldoc-hint)))
  (when (boundp 'eglot-events-buffer-config)
    (setq eglot-events-buffer-config
          (plist-put eglot-events-buffer-config :size 0)))

  (add-hook 'eglot-managed-mode-hook #'euler/lsp-sync-optimisation-mode)
  (advice-add 'eglot--managed-mode :around #'euler/lsp-defer-eglot-shutdown-a)

  )

;; Speed bonus for LSP. Requires the `emacs-lsp-booster' binary.
(use-package eglot-booster
  :ensure t
  :after eglot
  :if (executable-find "emacs-lsp-booster")
  :init
  (setq eglot-booster-io-only
        (and (> emacs-major-version 29)
             (not (functionp 'json-rpc-connection))))
  :config (eglot-booster-mode))

(use-package consult-eglot
  :ensure t
  :after eglot
  :commands consult-eglot-symbols
  :init
  (dysthesis/start/leader-keys
    "c j" '(consult-eglot-symbols :which-key "Symbols"))
  (with-eval-after-load 'eglot
    (define-key eglot-mode-map [remap xref-find-apropos] #'consult-eglot-symbols)))

(provide 'tools/lsp)
