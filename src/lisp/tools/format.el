;;; -*- lexical-binding: t; -*-
(require 'core/lib)

(defcustom euler/format-on-save-disabled-modes
  '(sql-mode
    tex-mode
    latex-mode
    LaTeX-mode
    org-msg-edit-mode)
  "Major modes where format-on-save should not be enabled.
If t, disable format-on-save in every mode.  If nil, enable it in
every mode."
  :type '(choice (const :tag "Disable all" t)
                 (const :tag "Disable none" nil)
                 (repeat :tag "Disabled modes" symbol))
  :group 'euler)

(defvaralias 'euler/format-with 'apheleia-formatter)
(defvaralias 'euler/format-inhibit 'apheleia-inhibit)

;; Apheleia does not define a keymap itself, but `define-minor-mode'
;; will use this predeclared map when it creates `apheleia-mode'.
(defvar apheleia-mode)
(defvar apheleia-mode-map (make-sparse-keymap)
  "Keymap for `apheleia-mode'.")

(defvar json-array-type)
(defvar json-false)
(defvar json-key-type)
(defvar json-object-type)

(defvar euler/format-eglot--last nil
  "Previous `euler/format-with' value before Eglot formatting took over.")

(defun euler/format-maybe-inhibit ()
  "Return non-nil when format-on-save should not auto-enable here."
  (let ((disabled euler/format-on-save-disabled-modes))
    (or (eq major-mode 'fundamental-mode)
        (euler/string-blank-p (buffer-name))
        (eq disabled t)
        (memq major-mode (ensure-list disabled)))))

(defun euler/format-refresh-after-local-vars ()
  "Apply format-on-save settings after file and directory locals."
  (when (boundp 'apheleia-mode)
    (if (or (bound-and-true-p apheleia-inhibit)
            (euler/format-maybe-inhibit))
        (when apheleia-mode
          (apheleia-mode -1))
      (when (bound-and-true-p apheleia-global-mode)
        (apheleia-mode 1)))))

(defun euler/format-save-buffer (arg)
  "Save current buffer, with prefix ARG inhibiting format-on-save."
  (interactive "P")
  (let ((apheleia-mode (and (bound-and-true-p apheleia-mode)
                            (memq arg '(nil 1)))))
    (call-interactively #'save-buffer)))

(defun euler/format--eglot-formatting-capable-p ()
  "Return non-nil when current Eglot server can format this buffer."
  (and (bound-and-true-p eglot--managed-mode)
       (or (eglot-server-capable :documentFormattingProvider)
           (eglot-server-capable :documentRangeFormattingProvider))))

(define-minor-mode euler/format-with-eglot-mode
  "Use Eglot as the first Apheleia formatter in this buffer."
  :init-value nil
  (unless (local-variable-p 'euler/format-eglot--last)
    (setq-local euler/format-eglot--last euler/format-with))
  (setq-local euler/format-with
	      (if euler/format-with-eglot-mode
                  (cons 'eglot
                        (euler/remove-if
                         (lambda (formatter)
                           (eq formatter 'eglot))
                         (ensure-list euler/format-with)))
                (prog1 (remq 'eglot (ensure-list euler/format-eglot--last))
                  (kill-local-variable 'euler/format-eglot--last)))))

(defun euler/format-with-eglot-toggle ()
  "Use Eglot formatting when it is available and no formatter is pinned."
  (when (or (null euler/format-with)
            euler/format-with-eglot-mode)
    (euler/format-with-eglot-mode
     (if (euler/format--eglot-formatting-capable-p) 1 -1))))

(defun euler/format--eglot-options ()
  "Return LSP formatting options for Eglot."
  (list :tabSize tab-width
        :insertSpaces (if indent-tabs-mode :json-false t)
        :insertFinalNewline (if require-final-newline t :json-false)
        :trimFinalNewlines (if delete-trailing-lines t :json-false)))

(defun euler/format--eglot-range-params ()
  "Return range-formatting params covering the current buffer."
  (save-excursion
    (list :range (list :start (eglot--pos-to-lsp-position (point-min))
		       :end (eglot--pos-to-lsp-position (point-max))))))

(defun euler/format-eglot-buffer (&rest args)
  "Format BUFFER with Eglot and apply edits to Apheleia SCRATCH."
  (require 'eglot)
  (let ((buffer (plist-get args :buffer))
        (scratch (plist-get args :scratch))
        (callback (plist-get args :callback))
        edits error linepos-fn move-fn)
    (with-current-buffer buffer
      (setq linepos-fn eglot-current-linepos-function
            move-fn eglot-move-to-linepos-function)
      (condition-case err
          (cond
           ((and (bound-and-true-p eglot--managed-mode)
                 (eglot-server-capable :documentFormattingProvider))
            (setq edits
                  (eglot--request
                   (eglot--current-server-or-lose)
                   :textDocument/formatting
                   (list :textDocument (eglot--TextDocumentIdentifier)
                         :options (euler/format--eglot-options)))))
           ((and (bound-and-true-p eglot--managed-mode)
                 (eglot-server-capable :documentRangeFormattingProvider))
            (setq edits
                  (eglot--request
                   (eglot--current-server-or-lose)
                   :textDocument/rangeFormatting
                   (list :textDocument (eglot--TextDocumentIdentifier)
                         :options (euler/format--eglot-options)
                         :range (plist-get (euler/format--eglot-range-params)
                                           :range)))))
           (t
            (setq error "Eglot server does not support formatting")))
        (error
         (setq error err))))
    (if error
        (funcall callback error)
      (with-current-buffer scratch
        (setq-local eglot-current-linepos-function linepos-fn
                    eglot-move-to-linepos-function move-fn)
        (eglot--apply-text-edits edits nil t))
      (funcall callback nil))))

(defun euler/format--clang-indent-style ()
  "Return clang-format fallback style from Emacs indentation settings."
  (when (and apheleia-formatters-respect-indent-level
             (not (locate-dominating-file default-directory ".clang-format")))
    (let ((indent (and (boundp 'c-basic-offset)
		       (symbol-value 'c-basic-offset))))
      (format "--style={IndentWidth: %d}"
	      (if (numberp indent) indent tab-width)))))

(defconst euler/format--prettier-config-files
  '(".prettierrc"
    ".prettierrc.json"
    ".prettierrc.yml"
    ".prettierrc.yaml"
    ".prettierrc.json5"
    ".prettierrc.js"
    "prettier.config.js"
    ".prettierrc.mjs"
    "prettier.config.mjs"
    ".prettierrc.cjs"
    "prettier.config.cjs"
    ".prettierrc.toml")
	  "Prettier config filenames that should override Emacs indentation.")

(defcustom euler/format-prettier-config-cache-ttl 30
  "Seconds to cache Prettier config discovery per directory."
  :type 'number
  :group 'euler)

(defvar euler/format--prettier-config-cache (make-hash-table :test 'equal)
  "Cache for `euler/format--prettier-configured-p'.")

(defun euler/format-clear-prettier-config-cache ()
  "Clear cached Prettier config discovery."
  (interactive)
  (clrhash euler/format--prettier-config-cache))

(defun euler/format--prettier-package-json-p ()
  "Return non-nil when nearest package.json has a prettier key."
  (let ((dir (locate-dominating-file default-directory "package.json")))
    (when dir
      (require 'json)
      (let ((json-key-type 'alist)
            (json-object-type 'alist)
            (json-array-type 'list)
            (json-false nil))
        (ignore-errors
          (assq 'prettier
                (json-read-file (expand-file-name "package.json" dir))))))))

(defun euler/format--prettier-configured-p ()
  "Return non-nil when current project has explicit Prettier config."
  (let* ((key (expand-file-name default-directory))
         (cached (gethash key euler/format--prettier-config-cache))
         (now (float-time)))
    (if (and cached
             (< (- now (car cached))
                euler/format-prettier-config-cache-ttl))
        (cdr cached)
      (let ((value
             (or (euler/some (lambda (file)
                               (locate-dominating-file default-directory file))
                             euler/format--prettier-config-files)
                 (euler/format--prettier-package-json-p))))
        (puthash key (cons now value) euler/format--prettier-config-cache)
        value))))

(defun euler/format--prettier-indent-args ()
  "Return Prettier indent args unless project config should decide."
  (when (and apheleia-formatters-respect-indent-level
             (not (euler/format--prettier-configured-p)))
    (apheleia-formatters-indent "--use-tabs" "--tab-width")))

(defun euler/format--prettier-indent-form-p (form)
  "Return non-nil when FORM adds Apheleia Prettier indent args."
  (memq (car-safe form)
        '(apheleia-formatters-js-indent
          apheleia-formatters-indent
          euler/format--prettier-indent-args)))

(defun euler/format--formatter (name)
  "Return Apheleia formatter command for NAME."
  (alist-get name (symbol-value 'apheleia-formatters)))

(defun euler/format--set-formatter (name command)
  "Set Apheleia formatter NAME to COMMAND."
  (set 'apheleia-formatters
       (cons (cons name command)
             (assq-delete-all name (symbol-value 'apheleia-formatters)))))

(use-package apheleia ;; stuff
  :ensure t
  :demand t
  :init
  (add-hook 'apheleia-inhibit-functions #'euler/format-maybe-inhibit)
  (with-eval-after-load 'eglot
    (add-hook 'eglot-managed-mode-hook #'euler/format-with-eglot-toggle))
  :config
  (push '(alejandra . ("alejandra" "-")) apheleia-formatters)
  (define-key apheleia-mode-map [remap save-buffer] #'euler/format-save-buffer)
  (define-key apheleia-mode-map [remap basic-save-buffer] #'euler/format-save-buffer)

  (add-hook 'hack-local-variables-hook #'euler/format-refresh-after-local-vars)

  (euler/format--set-formatter 'eglot #'euler/format-eglot-buffer)

  (dolist (entry '((sh-mode . shfmt)
                   (cuda-mode . clang-format)
                   (cuda-ts-mode . clang-format)
                   (protobuf-mode . clang-format)
		   (nix-mode . alejandra)
		   (nix-ts-mode . alejandra)))
    (add-to-list 'apheleia-mode-alist entry))

  (dolist (entry '((cuda-mode . ".cu")
                   (cuda-ts-mode . ".cu")
                   (glsl-ts-mode . ".glsl")
                   (protobuf-mode . ".proto")))
    (add-to-list 'apheleia-formatters-mode-extension-assoc entry))

  (euler/format--set-formatter
   'clang-format
   '("clang-format"
     "-assume-filename"
     (or (apheleia-formatters-local-buffer-file-name)
         (apheleia-formatters-mode-extension)
         ".c")
     (euler/format--clang-indent-style)))

  (dolist (formatter '(prettier
		       prettier-css
		       prettier-html
		       prettier-javascript
		       prettier-json
		       prettier-scss
		       prettier-svelte
		       prettier-typescript
		       prettier-yaml))
    (let ((command (euler/remove-if #'euler/format--prettier-indent-form-p
                                    (euler/format--formatter formatter))))
      (euler/format--set-formatter
       formatter
       (if command
           (append command '((euler/format--prettier-indent-args))) ; elsa-disable-line
         '((euler/format--prettier-indent-args))))))

  (apheleia-global-mode 1))

(provide 'tools/format)
