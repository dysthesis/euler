;;; Guardrail

(when (< emacs-major-version 29)
  (error "Euler only works with Emacs 29 and newer; you have version %s" emacs-major-version))

;; Packages come from Nix; keep `:ensure t' as a declaration for the Nix
;; scanner but make use-package skip the runtime package-install step.
(setq use-package-always-ensure nil
      use-package-ensure-function 'ignore)

(require 'cl-lib)

(defvar euler-inhibit-local-var-hooks nil
  "Non-nil disables Euler's MAJOR-MODE-local-vars-hook dispatcher.")

(defun euler/run-local-var-hooks ()
  "Run MAJOR-MODE-local-vars-hook after file and directory locals are set."
  (unless (or euler-inhibit-local-var-hooks
              delay-mode-hooks
              (minibufferp)
              (string-prefix-p
               " " (buffer-name (or (buffer-base-buffer)
                                     (current-buffer)))))
    (setq-local euler-inhibit-local-var-hooks t)
    (let ((hook-var (intern (format "%s-local-vars-hook" major-mode))))
      (unless (boundp hook-var)
        (set hook-var nil))
      (unless (get hook-var 'variable-documentation)
        (put hook-var 'variable-documentation
             (format "Hook run after file and directory locals are set in `%s'."
                     major-mode)))
      (run-hooks hook-var))))

(defun euler/run-local-var-hooks-maybe ()
  "Run local-var hooks when local variables are globally disabled."
  (unless enable-local-variables
    (euler/run-local-var-hooks)))

(add-hook 'after-change-major-mode-hook #'euler/run-local-var-hooks-maybe 100)
(add-hook 'hack-local-variables-hook #'euler/run-local-var-hooks)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Basic settings
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar user-cache-directory "~/.cache/emacs/"
  "Location where files created by emacs are placed.")

(use-package emacs
  :hook
  ;; Auto parenthesis matching
  ((prog-mode . electric-pair-mode))
  :config
  (setq major-mode-remap-alist
	'((yaml-mode . yaml-ts-mode)
	  (bash-mode . bash-ts-mode)
	  (c-mode . c-ts-mode)
	  (c++-mode . c++-ts-mode)
	  (cmake-mode . cmake-ts-mode)
	  (js2-mode . js-ts-mode)
	  (typescript-mode . typescript-ts-mode)
	  (json-mode . json-ts-mode)
	  (css-mode . css-ts-mode)
	  (python-mode . python-ts-mode)))
  ;; Built-in *-ts-mode keeps bracket/delimiter/operator faces at level 4.
  (setopt treesit-font-lock-level 4)
  ;; Mode line information
  (setopt column-number-mode t)                      ; Show column as well
  
  (setopt x-underline-at-descent-line nil)           ; Prettier underlines
  (setopt switch-to-buffer-obey-display-actions t)   ; Make switching buffers more consistent
  
  (setopt show-trailing-whitespace nil)      ; By default, don't underline trailing spaces
  (setopt indicate-buffer-boundaries 'left)  ; Show buffer top and bottom in the margin
  
  ;; Enable horizontal scrolling
  (setopt mouse-wheel-tilt-scroll t)
  (setopt mouse-wheel-flip-direction t)

  ;; PERF: Disable bidirectional text scanning. I don't use right-to-left languages (e.g., Arabic),
  ;; so this is a nice perf boost for me.
  (setq-default bidi-display-reordering 'left-to-right
                bidi-paragraph-direction 'left-to-right)
  (setq bidi-inhibit-bpa t)

  ;; PERF: Defer fontification until typing is done, in order to avoid micro-stutters, usually caused
  ;; by tree-sitter.
  (setq redisplay-skip-fontification-on-input t)

  ;; PERF: Don't render cursors in non-focused windows
  (setq-default cursor-in-non-selected-windows nil)
  (setq highlight-nonselected-windows nil)

  ;; Don't waste slots by saving duplicate entries in the kill-ring
  (setq kill-do-not-save-duplicates t)

  ;; Save clipboard before killing
  (setq save-interprogram-paste-before-kill t)

  ;; Persist kill-ring across sessions
  (setq savehist-additional-variables
      '(search-ring regexp-search-ring kill-ring))
  ;; Strip text properties that bloats the savehist file.
  (add-hook 'savehist-save-hook
            (lambda ()
              (setq kill-ring
                    (mapcar #'substring-no-properties
                            (cl-remove-if-not #'stringp kill-ring)))))

  ;; We won't set these, but they're good to know about
  ;;
  ;; (setopt indent-tabs-mode nil)
  ;; (setopt tab-width 4)
  
  ;; Misc. UI tweaks
  (blink-cursor-mode -1)                                ; Steady cursor
  (pixel-scroll-precision-mode)                         ; Smooth scrolling
  
  ;; Use common keystrokes by default
  (cua-mode)
  
  ;; For terminal users, make the mouse more useful
  
  (xterm-mouse-mode 1)
  
  ;; Display line numbers in programming mode
  (add-hook 'prog-mode-hook 'display-line-numbers-mode)
  (setopt display-line-numbers-width 3)           ; Set a minimum width
  
  ;; Nice line wrapping when working with text
  (add-hook 'text-mode-hook 'visual-line-mode)
  
  ;; Modes to highlight the current line with
  (let ((hl-line-hooks '(text-mode-hook prog-mode-hook)))
    (mapc (lambda (hook) (add-hook hook 'hl-line-mode)) hl-line-hooks))

  (tool-bar-mode 0)
  (menu-bar-mode 0)
  (scroll-bar-mode 0)
  (column-number-mode 1)
  (show-paren-mode 1)

  (setopt line-number-mode t)                        ; Show current line in modeline
  (setq display-line-numbers-type 'relative)
  (setopt initial-major-mode 'fundamental-mode)  ; default mode for the *scratch* buffer
  (setopt display-time-default-load-average nil) ; this information is useless for most

  ;; Automatically reread from disk if the underlying file changes
  (setopt auto-revert-avoid-polling t)
  ;; Some systems don't do file notifications well; see
  ;; https://todo.sr.ht/~ashton314/emacs-euler/11
  (setopt auto-revert-interval 5)
  (setopt auto-revert-check-vc-info t)
  (global-auto-revert-mode)

  ;; Save history of minibuffer
  (savehist-mode)
  ;; Move through windows with Ctrl-<arrow keys>
  (windmove-default-keybindings 'control) ; You can use other modifiers here

  ;; Fix archaic defaults
  (setopt sentence-end-double-space nil)

  ;; Make right-click do something sensible
  (when (display-graphic-p)
    (context-menu-mode))
  (setopt inhibit-splash-screen t)

  ;; Disable auto-backup
  (setq make-backup-files nil)
  ;; Disable auto-save
  (setq auto-save-default nil)

  (let* ((font-size
	  (let* ((hostname (car (split-string (system-name) "\\." t)))
		 (size-by-hostname '(("deimos" . 9)
				     ("phobos" . 9)))
		 (default-size 9))
	    (or (cdr (assoc hostname size-by-hostname))
		default-size)))
	 (font-height (* font-size 10)))
    (set-face-attribute 'default nil :family "JBMono Nerd Font" :height font-height)
    (set-fontset-font t nil (font-spec :size font-size :name "JBMono Nerd Font"))
    (setq-default line-spacing 0.2)
    (custom-theme-set-faces
     'user
     `(variable-pitch ((t (:family "Atkinson Hyperlegible Next" :height ,font-height))))
     `(fixed-pitch ((t (:family "JBMono Nerd Font" :height ,font-height))))))
  (add-to-list 'face-font-rescale-alist '("Atkinson Hyperlegible Next" . 1.2)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   UI Tweaks
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(load-theme 'noir t) ;; My own custom theme
(use-package solaire-mode
  :ensure t
  :config (solaire-global-mode +1))

(use-package ligature
  :ensure t
  :config
  ;; Enable the "www" ligature in every possible major mode
  (ligature-set-ligatures 't '("www"))
  ;; Enable traditional text ligatures in prose and documentation modes.
  (ligature-set-ligatures '(eww-mode org-mode markdown-mode help-mode Info-mode Man-mode woman-mode)
                          '("ff" "fi" "fl" "ffi" "ffl"))
  ;; Enable programming ligatures in programming modes.
  (ligature-set-ligatures 'prog-mode '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
                                       ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
                                       "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
                                       "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
                                       "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
                                       "..." "+++" "/==" "///" "_|_" "www" "&&" "^=" "~~" "~@" "~="
                                       "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
                                       "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
                                       ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
                                       "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
                                       "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
                                       "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "~~" "(*" "*)"
                                       "\\\\" "://"))
  ;; Typst derives from text-mode, so give it code-facing ligatures explicitly.
  (ligature-set-ligatures 'typst-ts-mode '("->" "=>" "<-" "<=" ">=" "==" "!=" "===" "!=="
                                           ":=" "::" "..." ".." "&&" "||" "//" "/*" "*/"))
  ;; Enables ligature checks globally in all buffers.  You can also do it
  ;; per mode with `ligature-mode'.
  (global-ligature-mode t))

(use-package hl-todo
  :ensure t
  :hook (prog-mode . global-hl-todo-mode)
  :config
  (setq hl-todo-highlight-punctuation ":"
	;; Don't highlight todo keywords in text-mode derivatives unless in
        ;; comments (e.g. data formats like yaml, json, etc).
        hl-todo-text-modes nil
	hl-todo-keyword-faces
        '(;; For reminders to change or add something at a later date.
          ("TODO" warning bold)
          ;; For code (or code paths) that are broken, unimplemented, or slow,
          ;; and may become bigger problems later.
          ("FIXME" error bold)
          ;; For code that needs to be revisited later, either to upstream it,
          ;; improve it, or address non-critical issues.
          ("REVIEW" font-lock-keyword-face bold)
          ;; For code smells where questionable practices are used intentionally
          ;; and is likely to break in a future update.
          ("HACK" font-lock-constant-face bold)
          ;; For sections of code that just gotta go, and will be gone soon.
          ;; Specifically, this means the code is deprecated, not necessarily
          ;; the feature it enables.
          ("DEPRECATED" font-lock-doc-face bold)
          ;; Extra keywords commonly found in the wild, whose meaning may vary
          ;; from project to project. Doom doesn't use BUG.
          ("BUG" error bold)
	  ;; Performance tricks
	  ("PERF" font-lock-constant-face bold)
          ;; Doom uses NOTE to indicate either A) this comment is about a code
          ;; omission, e.g. "I *would've* put X here, but I didn't because Y",
          ;; or B) it's a comment about a large section of code beyond the scope
          ;; of adjacent lines.
          ("NOTE" success bold))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Mode line
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'project)
(require 'subr-x)

(defface euler-mode-line-state
  '((t (:inherit mode-line-emphasis)))
  "Face for the Evil state segment in the Euler mode line.")

(defface euler-mode-line-icon
  '((t (:inherit shadow)))
  "Face for icons in the Euler mode line.")

(defface euler-mode-line-buffer
  '((t (:inherit mode-line-buffer-id)))
  "Face for the buffer name in the Euler mode line.")

(defface euler-mode-line-branch
  '((t (:inherit shadow)))
  "Face for the VC branch in the Euler mode line.")

(defface euler-mode-line-mode
  '((t (:inherit mode-line-emphasis)))
  "Face for the major mode segment in the Euler mode line.")

(defface euler-mode-line-muted
  '((t (:inherit shadow)))
  "Face for quiet metadata in the Euler mode line.")

(defface euler-mode-line-modified
  '((t (:inherit warning)))
  "Face for modified buffer state in the Euler mode line.")

(defface euler-mode-line-read-only
  '((t (:inherit shadow)))
  "Face for read-only buffer state in the Euler mode line.")

(defface euler-mode-line-position
  '((t (:inherit mode-line-emphasis)))
  "Face for cursor position in the Euler mode line.")

(defvar euler-mode-line-icons-enabled (require 'nerd-icons nil t)
  "Non-nil when Nerd Icons can be used in the Euler mode line.")

(defun euler/mode-line--truncate-left (text max-width)
  "Return TEXT shortened from the left to MAX-WIDTH characters."
  (let ((max-width (max 4 max-width)))
    (if (<= (length text) max-width)
        text
      (concat "..." (substring text (- (length text) (- max-width 3)))))))

(defun euler/mode-line--join (items)
  "Join non-empty ITEMS with quiet spacing."
  (string-join
   (delq nil
         (mapcar (lambda (item)
                   (when (and item (not (string-empty-p item)))
                     item))
                 items))
   "  "))

(defun euler/mode-line--pair (&rest items)
  "Join non-empty ITEMS as a compact icon/label pair."
  (string-join
   (delq nil
         (mapcar (lambda (item)
                   (when (and item (not (string-empty-p item)))
                     item))
                 items))
   " "))

(defun euler/mode-line--icon (icon fallback)
  "Return Nerd ICON or FALLBACK with icon styling."
  (propertize (or (and euler-mode-line-icons-enabled icon) fallback)
              'face 'euler-mode-line-icon))

(defun euler/mode-line--mode-icon ()
  "Return icon for the current major mode."
  (euler/mode-line--icon
   (when euler-mode-line-icons-enabled
     (ignore-errors (nerd-icons-icon-for-mode major-mode)))
   ":"))

(defun euler/mode-line--octicon (name fallback)
  "Return octicon NAME or FALLBACK."
  (euler/mode-line--icon
   (when euler-mode-line-icons-enabled
     (ignore-errors (nerd-icons-octicon name)))
   fallback))

(defun euler/mode-line--codicon (name fallback)
  "Return codicon NAME or FALLBACK."
  (euler/mode-line--icon
   (when euler-mode-line-icons-enabled
     (ignore-errors (nerd-icons-codicon name)))
   fallback))

(defun euler/mode-line-evil-state ()
  "Return compact Evil state indicator."
  (when (and (boundp 'evil-state) (bound-and-true-p evil-local-mode))
    (propertize
     (pcase evil-state
       ('normal "NOR")
       ('insert "INS")
       ('visual
        (pcase (and (boundp 'evil-visual-selection)
                    evil-visual-selection)
          ('line "V-LINE")
          ('block "V-BLOCK")
          (_ "VIS")))
       ('replace "REP")
       ('operator "OP")
       ('motion "MOT")
       ('emacs "EMACS")
       (_ "?"))
     'face 'euler-mode-line-state
     'help-echo (format "Evil state: %s" evil-state))))

(defun euler/mode-line-buffer-name ()
  "Return compact buffer name, relative to project when possible."
  (let* ((file (buffer-file-name))
         (root (when-let ((project (project-current nil)))
                 (expand-file-name (project-root project))))
         (name (cond
                ((and file root (file-in-directory-p file root))
                 (file-relative-name file root))
                (file
                 (abbreviate-file-name file))
                (t
                 (buffer-name))))
         (limit (max 20 (/ (window-total-width) 2))))
    (propertize
     (euler/mode-line--truncate-left name limit)
     'face 'euler-mode-line-buffer
     'help-echo (or file name))))

(defun euler/mode-line-buffer-status ()
  "Return modified/read-only buffer flags."
  (euler/mode-line--join
   (list
    (when buffer-read-only
      (propertize "RO" 'face 'euler-mode-line-read-only))
    (when (buffer-modified-p)
      (propertize "*" 'face 'euler-mode-line-modified)))))

(defun euler/mode-line-project-name ()
  "Return current project name."
  (when-let* ((project (project-current nil))
              (root (project-root project)))
    (unless (and buffer-file-name
                 (file-in-directory-p buffer-file-name root))
      (propertize
       (file-name-nondirectory
        (directory-file-name root))
       'face 'euler-mode-line-muted))))

(defun euler/mode-line-vc-branch ()
  "Return compact VC branch name."
  (when vc-mode
    (let* ((text (string-trim vc-mode))
           (branch (replace-regexp-in-string "\\`[[:alpha:]]+[:-]" "" text)))
      (unless (string-empty-p branch)
        (euler/mode-line--pair
         (euler/mode-line--octicon "nf-oct-git_branch" "git")
         (propertize branch 'face 'euler-mode-line-branch))))))

(defun euler/mode-line-major-mode ()
  "Return current major mode name."
  (euler/mode-line--pair
   (euler/mode-line--mode-icon)
   (propertize (or (alist-get major-mode
                              '((emacs-lisp-mode . "elisp")
                                (lisp-interaction-mode . "lisp")
                                (nix-mode . "nix")
                                (org-mode . "org")
                                (markdown-mode . "md"))
                              nil nil #'eq)
                  (replace-regexp-in-string
                   "\\(?:-ts\\)?-mode\\'" ""
                   (symbol-name major-mode)))
               'face 'euler-mode-line-mode)))

(defun euler/mode-line-position ()
  "Return current line and column."
  (euler/mode-line--pair
   (euler/mode-line--codicon "nf-cod-location" "@")
   (propertize (format "%d:%d" (line-number-at-pos) (current-column))
               'face 'euler-mode-line-position)))

(defun euler/mode-line-render (left right)
  "Render LEFT and RIGHT mode line segments."
  (let ((spacer-width (max 1 (- (window-total-width)
                                (string-width left)
                                (string-width right)
                                2))))
    (concat " " left (make-string spacer-width ?\s) right " ")))

(defun euler/mode-line ()
  "Return the Euler mode line."
  (euler/mode-line-render
   (euler/mode-line--join
    (list
     (euler/mode-line-evil-state)
     (euler/mode-line-buffer-name)
     (euler/mode-line-buffer-status)))
   (euler/mode-line--join
    (list
     (euler/mode-line-project-name)
     (euler/mode-line-vc-branch)
     (euler/mode-line-major-mode)
     (euler/mode-line-position)))))

(setq-default mode-line-format '((:eval (euler/mode-line))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Discovery aids
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; which-key: shows a popup of available keybindings when typing a long key
;; sequence (e.g. C-x ...)
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

;; Corfu: Popup completion-at-point
(use-package corfu
  :ensure t
  :init
  (global-corfu-mode)
  :custom
  (corfu-auto t)
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
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)
  (add-to-list 'completion-at-point-functions #'cape-file))

;; Pretty icons for corfu
(use-package nerd-icons-corfu
  :ensure t
  :after corfu
  :init (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(use-package nerd-icons-completion
  :ensure t
  :after marginalia
  :config (nerd-icons-completion-mode)
  :hook (marginalia-mode . nerd-icons-completion-marginalia-setup))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Interface enhancements/defaults
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Tab-bar configuration
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Show the tab-bar as soon as tab-bar functions are invoked
(setopt tab-bar-show 1)

;; Add the time to the tab-bar, if visible
(add-to-list 'tab-bar-format 'tab-bar-format-align-right 'append)
(add-to-list 'tab-bar-format 'tab-bar-format-global 'append)
(setopt display-time-format "%a %F %T")
(setopt display-time-interval 1)
(display-time-mode) 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Navigation
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package evil
  :ensure t
  :init
  (setq evil-want-integration t) ;; This is optional since it's already set to t by default.
  (setq evil-want-keybinding nil)
  :config
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :ensure t
  :config
  (evil-collection-init))

;; Quickly add parentheses around a selection by using `S-<paren>'
(use-package evil-surround
  :ensure t
  :config
  (global-evil-surround-mode 1))

(use-package evil-textobj-tree-sitter
  :ensure t)

;; Define the leader-key macro early so native compilation can expand it
;; before any package configs run.
(eval-and-compile
  (require 'general)
  (general-create-definer dysthesis/start/leader-keys
    :states '(normal insert visual motion emacs)
    :keymaps 'override
    :prefix "SPC"           ;; Set leader key
    :global-prefix "C-SPC")) ;; Set global leader key

(use-package general
  :ensure t
  :after (evil)
  :config
  (general-evil-setup)
  (dysthesis/start/leader-keys
   "." '(find-file :wk "Find file")
   "TAB" '(comment-line :wk "Comment lines"))
  (dysthesis/start/leader-keys
      "f" '(:ignore t :wk "Find")
      "f r" '(consult-recent-file :wk "Recent files")
      "f f" '(consult-fd :wk "Fd search for files")
      "f g" '(consult-ripgrep :wk "Ripgrep search in files")
      "f l" '(consult-line :wk "Find line")
      "f i" '(consult-imenu :wk "Imenu buffer locations")))

(use-package avy
  :ensure t
  :demand t
  :bind (("C-c j" . avy-goto-line)
         ("s-j"   . avy-goto-char-timer)))

;; Consult: Misc. enhanced commands
(use-package consult
  :ensure t
  :bind (
         ;; Drop-in replacements
         ("C-x b" . consult-buffer)     ; orig. switch-to-buffer
         ("M-y"   . consult-yank-pop)   ; orig. yank-pop
         ;; Searching
         ("M-s r" . consult-ripgrep)
         ("M-s l" . consult-line)       ; Alternative: rebind C-s to use
         ("M-s s" . consult-line)       ; consult-line instead of isearch, bind
         ("M-s L" . consult-line-multi) ; isearch to M-s s
         ("M-s o" . consult-outline)
         ;; Isearch integration
         :map isearch-mode-map
         ("M-e" . consult-isearch-history)   ; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history) ; orig. isearch-edit-string
         ("M-s l" . consult-line)            ; needed by consult-line to detect isearch
         ("M-s L" . consult-line-multi)      ; needed by consult-line to detect isearch
         )
  :config
  ;; Narrowing lets you restrict results to certain groups of candidates
  (setq consult-narrow-key "<"))

(use-package embark-consult
  :ensure t)

;; Embark: supercharged context-dependent menu; kinda like a
;; super-charged right-click.
(use-package embark
  :ensure t
  :demand t
  :after (avy embark-consult)
  :bind (("C-c a" . embark-act))        ; bind this to an easy key to hit
  :config
  ;; Add the option to run embark when using avy
  (defun euler/avy-action-embark (pt)
    "Run Embark at PT after jumping there with Avy."
    (unwind-protect
        (save-excursion
          (goto-char pt)
          (embark-act))
      (select-window
       (cdr (ring-ref avy-ring 0))))
    t)

  ;; After invoking avy-goto-char-timer, hit "." to run embark at the next
  ;; candidate you select
  (setf (alist-get ?. avy-dispatch-alist) 'euler/avy-action-embark))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Git
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package transient
  :ensure t)

(use-package magit
  :ensure t
  :after (transient)
  :config
  (dysthesis/start/leader-keys
    "g g" '(magit :wk "Magit")))

(use-package forge
  :ensure t
	:defer
  :after magit
  :config
  (setq auth-sources '("~/.authinfo.gpg"))
	(setq forge-bug-reference-remote-files nil
        forge-database-file
        (expand-file-name "forge-database.sqlite" user-cache-directory)))

(use-package magit-todos
	:ensure t
  :after magit
  :config (magit-todos-mode 1))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Development
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
  :ensure t)

(use-package json-mode
  :ensure t)

(defvar euler-tool-bin-directories
  (delete-dups
   (delq nil
         (mapcar (lambda (program)
                   (when-let ((path (executable-find program)))
                     (directory-file-name (file-name-directory path))))
                 '("emacs-lsp-booster"
                   "clangd"
                   "clang-format"
                   "cmake"
                   "cmake-language-server"))))
  "Tool directories from Euler's startup PATH to preserve in local envs.")

(defun euler/prepend-to-local-path (directories)
  "Prepend DIRECTORIES to buffer-local PATH and `exec-path'."
  (let (merged)
    (dolist (dir (append directories
                         (split-string (or (getenv "PATH") "") path-separator t)))
      (when (and (stringp dir)
                 (not (string-empty-p dir))
                 (not (member dir merged)))
        (push dir merged)))
    (setq merged (nreverse merged))
    (setenv "PATH" (string-join merged path-separator))
    (setq-local exec-path (append merged (and (memq nil exec-path) '(nil))))))

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
         (when-let ((root (locate-dominating-file path dir)))
           (expand-file-name dir root)))
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
    (cl-callf2 delete (list mode) major-mode-remap-defaults))

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

(use-package eglot
  :hook
  ((nix-mode . eglot-ensure))
  :custom
  (eglot-send-changes-idle-time 0.1)
  (eglot-extend-to-xref t)
  :config
  ;; PERF: Increase process output buffer for LSP, in order to reduce the number of
  ;; read calls Emacs has to make.
  (setq read-process-output-max (* 4 1024 1024))

  (dysthesis/start/leader-keys
     "c" '(:ignore t :which-key "Code")
     "c <escape>" '(keyboard-escape-quit :which-key t)
     "c r" '(eglot-rename :which-key "Rename")
     "c a" '(eglot-code-actions :which-key "Actions"))
  (fset #'jsonrpc--log-event #'ignore)  ; massive perf boost---don't log every event
  ;; Sometimes you need to tell Eglot where to find the language server
  (dolist (mode '(c-mode c-ts-mode c++-mode c++-ts-mode))
    (add-to-list
     'eglot-server-programs
     `(,mode . ("clangd" ,(format "-j=%d" (max 1 (/ (num-processors) 2)))))))
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nil")))
  (add-to-list 'eglot-server-programs
               '(((rustic-mode :language-id "rust") rust-mode rust-ts-mode)
                 . ("rust-analyzer"))))

;; Speed bonus for LSP. Requires the `emacs-lsp-booster' binary.
(use-package eglot-booster
  :ensure t
  :after eglot
  :if (executable-find "emacs-lsp-booster")
  :config (eglot-booster-mode))

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook (nix-mode . eglot-ensure))

(use-package rust-mode
  :ensure t
  :defer t
  :init
  (setq rust-mode-treesitter-derive t
        rust-indent-method-chain t))

(use-package rustic
  :ensure t
  :mode ("\\.rs\\'" . rustic-mode)
  :hook (rustic-mode . eglot-ensure)
  :init
  (setq rustic-babel-format-src-block nil
        rustic-format-trigger nil
        rustic-lsp-client 'eglot
        rustic-lsp-setup-p nil)
  :config
  (defun euler/rust-cargo-audit ()
    "Run cargo audit for the current Rust project."
    (interactive)
    (rustic-run-cargo-command `(,(rustic-cargo-bin) "audit")
                              (list :clippy-fix t
                                    :mode 'rustic-cargo-custom-command-mode)))

  (with-eval-after-load 'org-src
    (autoload 'org-babel-execute:rustic "rustic-babel")
    (defalias 'org-babel-execute:rust #'org-babel-execute:rustic)
    (add-to-list 'org-src-lang-modes '("rust" . rustic)))

  (add-to-list 'display-buffer-alist
               '("\\`\\*\\(rustic-compilation\\|cargo-run\\)"
                 (display-buffer-reuse-window display-buffer-at-bottom)
                 (window-height . 0.25)))

  (dysthesis/start/leader-keys
    :keymaps 'rustic-mode-map
    "m b" '(:ignore t :wk "Build")
    "m b a" '(euler/rust-cargo-audit :wk "Cargo audit")
    "m b b" '(rustic-cargo-build :wk "Cargo build")
    "m b B" '(rustic-cargo-bench :wk "Cargo bench")
    "m b c" '(rustic-cargo-check :wk "Cargo check")
    "m b C" '(rustic-cargo-clippy :wk "Cargo clippy")
    "m b d" '(rustic-cargo-build-doc :wk "Cargo doc")
    "m b D" '(rustic-cargo-doc :wk "Cargo doc --open")
    "m b f" '(rustic-cargo-fmt :wk "Cargo fmt")
    "m b n" '(rustic-cargo-new :wk "Cargo new")
    "m b o" '(rustic-cargo-outdated :wk "Cargo outdated")
    "m b r" '(rustic-cargo-run :wk "Cargo run")
    "m t" '(:ignore t :wk "Cargo test")
    "m t a" '(rustic-cargo-test :wk "All")
    "m t t" '(rustic-cargo-current-test :wk "Current test")))

;; Load direnv environments from .envrc
(use-package envrc
  :ensure t
  :config
  (defun euler/envrc-preserve-tool-paths (buffer result)
    "Keep Euler-provided tools discoverable after envrc updates BUFFER."
    (with-current-buffer buffer
      (when (and (listp result)
                 euler-tool-bin-directories)
        (euler/prepend-to-local-path euler-tool-bin-directories))))

  (advice-add 'envrc--apply :after #'euler/envrc-preserve-tool-paths)
  (envrc-global-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Templating
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package tempel
  :ensure t
  ;; By default, tempel looks at the file "templates" in
  ;; user-emacs-directory, but you can customize that with the
  ;; tempel-path variable:
  ;; :custom
  ;; (tempel-path (concat user-emacs-directory "custom_template_file"))
  :bind (("M-*" . tempel-insert)
         ("M-+" . tempel-complete)
         :map tempel-map
         ("C-c RET" . tempel-done)
         ("C-<down>" . tempel-next)
         ("C-<up>" . tempel-previous)
         ("M-<down>" . tempel-next)
         ("M-<up>" . tempel-previous))
  :init
  ;; Make a function that adds the tempel expansion function to the
  ;; list of completion-at-point-functions (capf).
  (defun tempel-setup-capf ()
    "Add Tempel expansion to local completion-at-point functions."
    (add-hook 'completion-at-point-functions #'tempel-expand -1 'local))
  ;; Put tempel-expand on the list whenever you start programming or
  ;; writing prose.


  (add-hook 'text-mode-hook 'tempel-setup-capf))

(use-package tempel-collection
  :ensure t
  :after tempel)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Org-mode
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package org
  :hook ((org-mode . visual-line-mode)  ; wrap lines at word breaks
         (org-mode . flyspell-mode)     ; spell checking!
	 (org-mode . org-indent-mode))    
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
