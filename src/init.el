;;; -*- lexical-binding: t; -*-
;;; Guardrail

(when (< emacs-major-version 29)
  (error "Euler only works with Emacs 29 and newer; you have version %s" emacs-major-version))

;; Packages come from Nix; keep `:ensure t' as a declaration for the Nix
;; scanner but make use-package skip the runtime package-install step.
(setq use-package-always-ensure nil
      use-package-ensure-function 'ignore)

(defun euler/find-if (predicate sequence)
  "Return the first item in SEQUENCE for which PREDICATE is non-nil."
  (catch 'found
    (dolist (item sequence)
      (when (funcall predicate item)
        (throw 'found item)))
    nil))

(defun euler/some (predicate sequence)
  "Return the first non-nil PREDICATE result for an item in SEQUENCE."
  (catch 'found
    (dolist (item sequence)
      (let ((result (funcall predicate item)))
        (when result
          (throw 'found result))))
    nil))

(defun euler/remove-if (predicate sequence)
  "Return a copy of SEQUENCE without items matching PREDICATE."
  (let (result)
    (dolist (item sequence (nreverse result))
      (unless (funcall predicate item)
        (push item result)))))

(defun euler/sequence-empty-p (sequence)
  "Return non-nil when SEQUENCE has no elements."
  (if (listp sequence)
      (null sequence)
    (= (length sequence) 0)))

(defun euler/string-join (strings separator)
  "Join STRINGS with SEPARATOR."
  (mapconcat #'identity strings separator))

(defun euler/string-empty-p (string)
  "Return non-nil when STRING is empty."
  (= (length string) 0))

(defun euler/string-blank-p (string)
  "Return non-nil when STRING contains only whitespace."
  (string-match-p "\\`[[:space:]]*\\'" string))

(defun euler/string-trim (string)
  "Return STRING without leading or trailing whitespace."
  (replace-regexp-in-string "\\`[[:space:]]+\\|[[:space:]]+\\'" "" string))

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
  (setq-default line-spacing 0.25)

  (setq-default display-fill-column-indicator-column 80)
  (setq-default display-fill-column-indicator-character ?\x2502)
  (set-face-attribute 'fill-column-indicator nil :background nil :foreground "gray3")
  (global-display-fill-column-indicator-mode 1)
  (setq major-mode-remap-alist
	'((yaml-mode . yaml-ts-mode)
	  (nix-mode . nix-ts-mode)
	  (bash-mode . bash-ts-mode)
	  (sh-mode . bash-ts-mode)
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
                            (delq nil
                                  (mapcar (lambda (item)
                                            (and (stringp item) item))
                                          kill-ring))))))

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

(use-package indent-bars
  :ensure t
  :unless noninteractive
  :hook (prog-mode . indent-bars-mode)
  :config
  (setq indent-bars-treesit-support t
	indent-bars-treesit-wrap '((python argument_list parameters
					   list list_comprehension
					   dictionary dictionary_comprehension
					   parenthesized_expression subscript)
				   (c argument_list parameter_list
				      init_declarator parenthesized_expression)
				   (rust trait_item impl_item 
					 macro_definition macro_invocation 
					 struct_item enum_item mod_item 
					 const_item let_declaration 
					 function_item for_expression 
					 if_expression loop_expression 
					 while_expression match_expression 
					 match_arm call_expression 
					 token_tree token_tree_pattern 
					 token_repetition)
				   (toml table array comment)
				   (yaml block_mapping_pair comment))
	indent-bars-treesit-wrap '((rust arguments parameters))
        indent-bars-prefer-character
        (or
         ;; Bitmaps are far slower on MacOS, inexplicably, but this needs more
         ;; testing to see if it's specific to ns or emacs-mac builds, or is
         ;; just a general MacOS issue.
         (featurep :system 'macos)
         ;; FIX: A bitmap init bug in emacs-pgtk (before v30) could cause
         ;; crashes (see jdtsmith/indent-bars#3).
         (and (featurep 'pgtk)
              (< emacs-major-version 30)))
	;; Show indent guides starting from the first column.
        indent-bars-starting-column 0
        ;; Make indent guides subtle; the default is too distractingly colorful.
        indent-bars-width-frac 0.15  ; make bitmaps thinner
        indent-bars-color-by-depth nil
        indent-bars-color '(font-lock-comment-face :face-bg nil :blend 0.425)
        ;; Don't highlight current level indentation; it's distracting and is
        ;; unnecessary overhead for little benefit.
        indent-bars-highlight-current-depth nil
        ;; The default is `t', which shows indent-bars even on blank lines
        ;; beyond the end of an indented block. Setting it to `nil' will cause
        ;; gaps in the indent guides, which looks odd. `least' is a good
        ;; compromise, and doesn't suffer the scrolling issue.
        indent-bars-display-on-blank-lines 'least))

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
  (euler/string-join
   (delq nil
         (mapcar (lambda (item)
                   (when (and item (not (euler/string-empty-p item)))
                     item))
                 items))
   "  "))

(defun euler/mode-line--pair (&rest items)
  "Join non-empty ITEMS as a compact icon/label pair."
  (euler/string-join
   (delq nil
         (mapcar (lambda (item)
                   (when (and item (not (euler/string-empty-p item)))
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
         (root (let ((project (project-current nil)))
                 (when project
                   (expand-file-name (project-root project)))))
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
  (let ((project (project-current nil)))
    (when project
      (let ((root (project-root project)))
        (when root
          (unless (and buffer-file-name
		       (file-in-directory-p buffer-file-name root))
            (propertize
             (file-name-nondirectory
	      (directory-file-name root))
             'face 'euler-mode-line-muted)))))))

(defun euler/mode-line-vc-branch ()
  "Return compact VC branch name."
  (when vc-mode
    (let* ((text (euler/string-trim vc-mode))
           (branch (replace-regexp-in-string "\\`[[:alpha:]]+[:-]" "" text)))
      (unless (euler/string-empty-p branch)
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

(defvar evil-collection-magit-use-z-for-folds)
(defvar evil-collection-magit-section-use-z-for-folds)

(use-package evil-collection
  :after evil
  :ensure t
  :init
  (setq evil-collection-magit-use-z-for-folds t
        evil-collection-magit-section-use-z-for-folds t)
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
;;;   Files
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar dired-actual-switches)
(defvar dired-auto-revert-buffer)
(defvar dired-clean-confirm-killing-deleted-buffers)
(defvar dired-create-destination-dirs)
(defvar dired-dwim-target)
(defvar dired-guess-shell-alist-user)
(defvar dired-listing-switches)
(defvar dired-mode-map)
(defvar dired-omit-files)
(defvar dired-omit-verbose)
(defvar dired-recursive-copies)
(defvar dired-recursive-deletes)
(defvar dired-use-ls-dired)
(defvar dired-vc-rename-file)
(defvar dirvish-attributes)
(defvar dirvish-cache-dir)
(defvar dirvish-header-line-height)
(defvar dirvish-hide-cursor)
(defvar dirvish-hide-details)
(defvar dirvish-mode-line-format)
(defvar dirvish-mode-line-height)
(defvar dirvish-mode-map)
(defvar dirvish-reuse-session)
(defvar dirvish-subtree-always-show-state)
(defvar dirvish-use-header-line)
(defvar dirvish-use-mode-line)
(defvar image-dired-db-file)
(defvar image-dired-dir)
(defvar image-dired-gallery-dir)
(defvar image-dired-temp-image-file)
(defvar image-dired-temp-rotate-image-file)
(defvar image-dired-thumb-size)
(defvar insert-directory-program)
(defvar ls-lisp-use-insert-directory-program)
(defvar revert-buffer-function)
(defvar wdired-mode-map)

(declare-function dirvish-curr "dirvish")
(declare-function dirvish-quit "dirvish")
(declare-function wdired-exit "wdired")

(defconst euler/dired-basic-listing-switches "-ahl"
  "Portable Dired listing switches.")

(defconst euler/dired-gnu-listing-switches '("-ahl" "-v" "--group-directories-first")
  "Dired listing switches for GNU ls.")

(defun euler/dired--gnu-ls-p (program)
  "Return non-nil when PROGRAM looks like GNU ls."
  (when (and program (executable-find program))
    (with-temp-buffer
      (and (zerop (call-process program nil t nil "--version"))
           (goto-char (point-min))
           (re-search-forward "\\bGNU coreutils\\b" nil t)))))

(defun euler/dired-configure-listing-switches ()
  "Prefer GNU ls switches, falling back to portable Dired switches."
  (let* ((current-ls (or (and (boundp 'insert-directory-program)
			      insert-directory-program)
                         "ls"))
         (gnu-ls (cond
                  ((euler/dired--gnu-ls-p current-ls)
                   current-ls)
                  ((and (executable-find "gls")
                        (euler/dired--gnu-ls-p "gls"))
                   "gls"))))
    (if gnu-ls
        (setq insert-directory-program gnu-ls
	      dired-listing-switches
	      (euler/string-join euler/dired-gnu-listing-switches " "))
      (setq dired-use-ls-dired nil
            dired-listing-switches euler/dired-basic-listing-switches))))

(defun euler/dired-disable-gnu-ls-flags-maybe ()
  "Drop GNU-only Dired switches where they are not safe."
  (when (or (file-remote-p default-directory)
            (and (boundp 'ls-lisp-use-insert-directory-program)
                 (not ls-lisp-use-insert-directory-program)))
    (setq-local dired-actual-switches euler/dired-basic-listing-switches)))

(defun euler/dired-buffer-stale-p-unless-virtual (fn &rest args)
  "Call FN with ARGS unless current Dired buffer is virtual."
  (and (not (eq revert-buffer-function #'dired-virtual-revert))
       (apply fn args)))

(defun euler/wdired-exit ()
  "Exit Wdired from an escape key binding."
  (interactive)
  (wdired-exit))

(defun euler/dirvish-debounce-redisplay (fn window)
  "Call Dirvish redisplay FN for WINDOW only in its selected frame."
  (when (eq (frame-selected-window (window-frame window)) window)
    (funcall fn window)))

(defun euler/dirvish-cleanup (&rest _)
  "Quit the active Dirvish session before project/window context changes."
  (when (and (featurep 'dirvish)
             (fboundp 'dirvish-curr))
    (catch 'done
      (dolist (window (window-list nil 'no-minibuf t))
        (when (and (window-live-p window)
                   (window-dedicated-p window))
          (with-current-buffer (window-buffer window)
            (when (dirvish-curr)
	      (let ((dirvish-reuse-session nil))
                (let ((selected-window (selected-window)))
                  (unwind-protect
		      (progn
                        (select-window window)
                        (dirvish-quit))
                    (when (window-live-p selected-window)
		      (select-window selected-window)))))
	      (throw 'done t))))))))

(defun euler/dired-open-externally-command ()
  "Return a platform command for opening files outside Emacs."
  (pcase system-type
    ('darwin "open")
    ('gnu/linux "xdg-open")
    ('windows-nt "start")))

(use-package dired
  :ensure nil
  :commands dired-jump
  :init
  (setq dired-dwim-target t
        dired-auto-revert-buffer #'dired-buffer-stale-p
        dired-recursive-copies 'always
        dired-recursive-deletes 'top
        dired-create-destination-dirs 'ask
        image-dired-dir (file-name-concat user-cache-directory "image-dired/")
        image-dired-db-file (file-name-concat image-dired-dir "db.el")
        image-dired-gallery-dir (file-name-concat image-dired-dir "gallery/")
        image-dired-temp-image-file (file-name-concat image-dired-dir "temp-image")
        image-dired-temp-rotate-image-file (file-name-concat image-dired-dir "temp-rotate-image")
        image-dired-thumb-size 150)
  :config
  (euler/dired-configure-listing-switches)
  (add-hook 'dired-mode-hook #'euler/dired-disable-gnu-ls-flags-maybe)
  (add-hook 'dired-mode-hook #'dired-hide-details-mode)
  (put 'dired-find-alternate-file 'disabled nil)
  (advice-add 'dired-buffer-stale-p :around #'euler/dired-buffer-stale-p-unless-virtual)
  (define-key dired-mode-map (kbd "C-c C-e") #'wdired-change-to-wdired-mode))

(use-package dirvish
  :ensure t
  :commands (dirvish-dired-noselect-a dirvish--find-entry)
  :init
  (setq dirvish-cache-dir (file-name-concat user-cache-directory "dirvish/")
        dirvish-hide-details '(dired dirvish dirvish-side)
        dirvish-hide-cursor '(dired dirvish dirvish-side))
  (with-eval-after-load 'dired
    (advice-add 'dired--find-file :override #'dirvish--find-entry)
    (advice-add 'dired-noselect :around #'dirvish-dired-noselect-a))
  :config
  (dirvish-override-dired-mode)
  (advice-add 'dirvish-pre-redisplay-h :around #'euler/dirvish-debounce-redisplay)

  (setq dirvish-reuse-session 'open
        dirvish-attributes '(file-size nerd-icons subtree-state)
        dirvish-subtree-always-show-state t
        dirvish-mode-line-format
        '(:left (sort file-time symlink) :right (omit yank index))
        dirvish-use-header-line t
        dirvish-use-mode-line t
        dirvish-hide-details '(dired dirvish dirvish-side)
        dirvish-hide-cursor '(dired dirvish dirvish-side))

  (general-define-key
   :keymaps 'dired-mode-map
   "C-c C-r" #'dirvish-rsync)

  (general-define-key
   :states 'normal
   :keymaps 'dirvish-mode-map
   "?" #'dirvish-dispatch
   "q" #'dirvish-quit
   "b" #'dirvish-quick-access
   "f" #'dirvish-file-info-menu
   "p" #'dirvish-yank
   "S" #'dirvish-quicksort
   "F" #'dirvish-layout-toggle
   "z" #'dirvish-history-jump
   "gh" #'dirvish-subtree-up
   "gl" #'dirvish-subtree-toggle
   "h" #'dired-up-directory
   "l" #'dired-find-file
   "TAB" #'dirvish-subtree-toggle
   "M-b" #'dirvish-history-go-backward
   "M-f" #'dirvish-history-go-forward
   "M-n" #'dirvish-narrow
   "M-m" #'dirvish-mark-menu
   "M-s" #'dirvish-setup-menu
   "M-e" #'dirvish-emerge-menu)

  (general-define-key
   :states 'motion
   :keymaps 'dirvish-mode-map
   "<left>" #'dired-up-directory
   "<right>" #'dired-find-file
   "[h" #'dirvish-history-go-backward
   "]h" #'dirvish-history-go-forward
   "[e" #'dirvish-emerge-next-group
   "]e" #'dirvish-emerge-previous-group)

  (general-define-key
   :states '(normal motion)
   :keymaps 'dirvish-mode-map
   "<left>" #'dired-up-directory
   "<right>" #'dired-find-file
   "M-b" #'dirvish-history-go-backward
   "M-f" #'dirvish-history-go-forward
   "M-n" #'dirvish-narrow
   "M-m" #'dirvish-mark-menu
   "M-s" #'dirvish-setup-menu
   "M-e" #'dirvish-emerge-menu)

  (general-define-key
   :states 'normal
   :keymaps 'dirvish-mode-map
   :prefix "y"
   "l" #'dirvish-copy-file-true-path
   "n" #'dirvish-copy-file-name
   "p" #'dirvish-copy-file-path
   "r" #'dirvish-copy-remote-path
   "y" #'dired-do-copy)

  (general-define-key
   :states 'normal
   :keymaps 'dirvish-mode-map
   :prefix "s"
   "s" #'dirvish-symlink
   "S" #'dirvish-relative-symlink
   "h" #'dirvish-hardlink)

  (advice-add 'project-switch-project :before #'euler/dirvish-cleanup))

(use-package diredfl
  :ensure t
  :hook ((dired-mode . diredfl-mode)
         (dirvish-directory-view-mode . diredfl-mode)))

(use-package dired-x
  :ensure nil
  :hook (dired-mode . dired-omit-mode)
  :config
  (setq dired-omit-verbose nil
        dired-omit-files
        (concat dired-omit-files
                "\\|^\\.DS_Store\\'"
                "\\|^flycheck_.*"
                "\\|^\\.project\\(?:ile\\)?\\'"
                "\\|^\\.\\(?:svn\\|git\\)\\'"
                "\\|^\\.ccls-cache\\'"
                "\\|\\(?:\\.js\\)?\\.meta\\'"
                "\\|\\.\\(?:elc\\|o\\|pyo\\|swp\\|class\\)\\'"))
  (setq dired-clean-confirm-killing-deleted-buffers nil)
  (let ((cmd (euler/dired-open-externally-command)))
    (when cmd
      (setq dired-guess-shell-alist-user
            `(("\\.\\(?:docx\\|pdf\\|djvu\\|eps\\)\\'" ,cmd)
	      ("\\.\\(?:jpe?g\\|png\\|gif\\|xpm\\)\\'" ,cmd)
	      ("\\.xcf\\'" ,cmd)
	      ("\\.csv\\'" ,cmd)
	      ("\\.tex\\'" ,cmd)
	      ("\\.\\(?:mp4\\|mkv\\|avi\\|flv\\|rm\\|rmvb\\|ogv\\)\\(?:\\.part\\)?\\'" ,cmd)
	      ("\\.\\(?:mp3\\|flac\\)\\'" ,cmd)
	      ("\\.html?\\'" ,cmd)
	      ("\\.md\\'" ,cmd)))))
  (general-define-key
   :states '(normal motion)
   :keymaps 'dired-mode-map
   "SPC" nil
   "SPC m h" #'dired-omit-mode))

(use-package dired-aux
  :ensure nil
  :defer t
  :config
  (setq dired-create-destination-dirs 'ask
        dired-vc-rename-file t))

(use-package wdired
  :ensure nil
  :defer t
  :config
  (define-key wdired-mode-map (kbd "<escape>") #'euler/wdired-exit)
  (define-key wdired-mode-map [escape] #'euler/wdired-exit))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Git
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defgroup euler/magit nil
  "Euler Magit integration."
  :group 'tools)

(defcustom euler/magit-open-windows-in-direction 'right
  "Direction to open Magit side buffers from the status buffer."
  :type '(choice (const left)
                 (const right)
                 (const up)
                 (const down))
  :group 'euler/magit)

(defcustom euler/magit-fringe-size '(13 . 1)
  "Fringe size in Magit buffers.
May be an integer or a cons cell of left and right fringe widths."
  :type '(choice integer
                 (cons integer integer)
                 (const nil))
  :group 'euler/magit)

(defvar-local euler/magit--refreshed-buffer nil
  "Magit buffer point/window state saved before refresh.")

(defun euler/magit--opposite-direction (direction)
  "Return the opposite window direction for DIRECTION."
  (pcase direction
    ('right 'left)
    ('left 'right)
    ((or 'up 'above) 'down)
    ((or 'down 'below) 'up)))

(defun euler/magit--split-side (direction)
  "Return a `split-window' SIDE for DIRECTION."
  (pcase direction
    ('up 'above)
    ('down 'below)
    (_ direction)))

(defun euler/magit--display-buffer-in-direction (buffer alist)
  "Display BUFFER in a nearby window according to ALIST."
  (let* ((direction (or (alist-get 'direction alist)
                        euler/magit-open-windows-in-direction))
         (origin-window (selected-window))
         (window (or (window-in-direction direction)
                     (and (not (one-window-p))
                          (window-in-direction
                           (euler/magit--opposite-direction direction)))
                     (split-window nil nil (euler/magit--split-side direction)))))
    (display-buffer-record-window 'reuse window buffer)
    (set-window-buffer window buffer)
    (set-window-parameter window 'quit-restore
                          (list 'window 'window origin-window buffer))
    (unless (bound-and-true-p magit-display-buffer-noselect)
      (select-window window)
      (switch-to-buffer buffer t t))
    window))

(defun euler/magit-display-buffer (buffer)
  "Display Magit BUFFER using Euler's window policy."
  (let ((buffer-mode (buffer-local-value 'major-mode buffer)))
    (display-buffer
     buffer
     (cond
      ((and (eq buffer-mode 'magit-status-mode)
            (get-buffer-window buffer))
       '(display-buffer-reuse-window))
      ((or (bound-and-true-p git-commit-mode)
           (eq buffer-mode 'magit-process-mode)
           (eq major-mode 'magit-log-select-mode))
       (let ((size (if (eq buffer-mode 'magit-process-mode) 0.35 0.7)))
         `(display-buffer-below-selected
           . ((window-height . ,(truncate (* (window-height) size)))))))
      ((or (not (derived-mode-p 'magit-mode))
           (and (eq major-mode 'magit-status-mode)
                (memq buffer-mode '(magit-diff-mode magit-stash-mode)))
           (not (memq buffer-mode
		      '(magit-process-mode
                        magit-revision-mode
                        magit-stash-mode
                        magit-status-mode))))
       '(display-buffer-same-window))
      (t
       '(euler/magit--display-buffer-in-direction))))))

(defun euler/magit-save-window-state ()
  "Save point and window start before refreshing an active Magit region."
  (when (use-region-p)
    (setq-local euler/magit--refreshed-buffer
                (list (current-buffer) (point) (window-start)))))

(defun euler/magit-restore-window-state ()
  "Restore point and window start after refreshing an active Magit region."
  (pcase-let ((`(,buffer ,point ,start) euler/magit--refreshed-buffer))
    (when (and buffer (eq (current-buffer) buffer))
      (goto-char point)
      (set-window-start nil start t)
      (kill-local-variable 'euler/magit--refreshed-buffer))))

(defun euler/magit-enlarge-fringe ()
  "Use a wider fringe in Magit section buffers."
  (when (and (display-graphic-p)
             (derived-mode-p 'magit-section-mode)
             euler/magit-fringe-size)
    (let ((left (or (car-safe euler/magit-fringe-size)
                    euler/magit-fringe-size))
          (right (or (cdr-safe euler/magit-fringe-size)
                     euler/magit-fringe-size)))
      (unless (and (= left (or left-fringe-width 0))
                   (= right (or right-fringe-width 0)))
        (set-window-fringes nil left right)))))

(defun euler/magit-install-fringe-hook ()
  "Install Magit fringe adjustment in the current buffer."
  (add-hook 'window-configuration-change-hook #'euler/magit-enlarge-fringe nil t)
  (euler/magit-enlarge-fringe))

(defun euler/magit-reveal-point-if-invisible ()
  "Reveal point after visiting a file from Magit."
  (if (derived-mode-p 'org-mode)
      (org-reveal '(4))
    (require 'reveal)
    (reveal-post-command)))

(defun euler/magit-quit (&optional kill-buffer)
  "Quit current Magit buffer.
With KILL-BUFFER, kill it.  If no Magit windows for this repository
remain, kill all Magit buffers for the repository."
  (interactive "P")
  (let ((topdir (magit-toplevel)))
    (funcall magit-bury-buffer-function kill-buffer)
    (unless (euler/find-if
             (lambda (window)
	       (with-selected-window window
                 (and (derived-mode-p 'magit-mode)
		      (equal magit--default-directory topdir))))
             (window-list nil 'no-minibuf t))
      (euler/magit-quit-all))))

(defun euler/magit-quit-all ()
  "Kill all Magit buffers for the current repository."
  (interactive)
  (mapc #'euler/magit--kill-buffer (magit-mode-get-buffers)))

(defun euler/magit--kill-buffer (buf)
  "Kill Magit BUF, waiting for live processes to finish."
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (let ((process (get-buffer-process (current-buffer))))
        (if (and process (process-live-p process))
            (run-with-timer 5 nil #'euler/magit--kill-buffer (current-buffer))
          (kill-buffer (current-buffer)))))))

(defun euler/git-commit-start-in-insert-state-maybe ()
  "Start blank commit messages in Evil insert state."
  (when (and (bound-and-true-p evil-local-mode)
             (fboundp 'evil-insert-state)
             (not (and (fboundp 'evil-emacs-state-p)
		       (evil-emacs-state-p)))
             (bobp)
             (eolp))
    (evil-insert-state)))

(use-package transient
  :ensure t
  :init
  (setq transient-levels-file
        (file-name-concat user-cache-directory "transient" "levels")
        transient-values-file
        (file-name-concat user-cache-directory "transient" "values")
        transient-history-file
        (file-name-concat user-cache-directory "transient" "history")))

(use-package magit
  :ensure t
  :after (transient)
  :init
  ;; Euler already uses `global-auto-revert-mode'; do not duplicate reverts.
  (setq magit-auto-revert-mode nil)
  :config
  (magit-auto-revert-mode -1)
  (setq transient-default-level 5
        magit-diff-refine-hunk t
        magit-save-repository-buffers nil
        magit-revision-insert-related-refs nil
        magit-uniquify-buffer-names nil
        magit-git-executable (or (executable-find magit-git-executable) "git")
        magit-display-buffer-function #'euler/magit-display-buffer
        magit-bury-buffer-function #'magit-mode-quit-window
        transient-display-buffer-action
        '(display-buffer-below-selected
          (dedicated . t)
          (inhibit-same-window . t))
        transient-show-during-minibuffer-read t)

  (add-hook 'magit-process-mode-hook #'goto-address-mode)
  (add-hook 'magit-pre-refresh-hook #'euler/magit-save-window-state)
  (add-hook 'magit-post-refresh-hook #'euler/magit-restore-window-state)
  (add-hook 'magit-section-mode-hook #'euler/magit-install-fringe-hook)
  (add-hook 'magit-diff-visit-file-hook #'euler/magit-reveal-point-if-invisible)
  (add-hook 'magit-status-mode-hook
            (lambda ()
	      (setq-local long-line-threshold nil)))

  (transient-append-suffix 'magit-fetch "-p"
    '("-t" "Fetch all tags" ("-t" "--tags")))
  (transient-append-suffix 'magit-pull "-r"
    '("-a" "Autostash" "--autostash"))

  (define-key magit-mode-map (kbd "q") #'euler/magit-quit)
  (define-key magit-mode-map (kbd "Q") #'euler/magit-quit-all)
  (define-key transient-map [escape] #'transient-quit-one)

  (dysthesis/start/leader-keys
    "g g" '(magit :wk "Ma[G]it")))

;; TODO: Add support in noir-theme
;; TODO: Custom commands like `tug' to pull along bookmarks to @-
(use-package majutsu
  :ensure t
  :after (transient)
  :config (dysthesis/start/leader-keys
	    "g j" '(majutsu :wk "Ma[J]utsu")))

(use-package diff-hl
  :ensure t
  :demand t
  :preface
  (defvar diff-hl-side)
  (defvar text-scale-mode-amount)
  (defvar text-scale-mode-step)
  :custom
  (vc-git-diff-switches '("--histogram"))
  (diff-hl-flydiff-delay 0.5)
  (diff-hl-update-async t)
  (diff-hl-show-staged-changes nil)
  (diff-hl-draw-borders nil)
  :hook (vc-dir-mode . turn-on-diff-hl-mode)
  :hook (diff-hl-mode . diff-hl-flydiff-mode)
  :config
  (if (fboundp 'fringe-mode) (fringe-mode '8))
  (setq-default fringes-outside-margins t)
  (global-diff-hl-mode)
  ;; from https://github.com/jidibinlin/.emacs.d/blob/d5332b2a7877126e83dc3dc0c94e1c66dd5446c0/lisp/init-vc.el#L56C2-L91C69
  (defun dysthesis/pretty-diff-hl-fringe (&rest _)
    (let* ((scale (if (and (boundp 'text-scale-mode-amount)
  			   (numberp text-scale-mode-amount))
  		      (expt text-scale-mode-step text-scale-mode-amount)
  		    1))
	   (spacing (or (and (display-graphic-p) (default-value 'line-spacing)) 0))
	   (h (+ (ceiling (* (frame-char-height) scale))
		 (if (floatp spacing)
		     (truncate (* (frame-char-height) spacing)) ; elsa-disable-line
		   spacing)))
  	   (w (min (frame-parameter nil (intern (format "%s-fringe" diff-hl-side)))
  		   16))
  	   (_ (if (zerop w) (setq w 16))))

      (define-fringe-bitmap 'diff-hl-bmp-middle
  	(make-vector
  	 h (string-to-number (let ((half-w (1- (/ w 2))))
  			       (concat (make-string half-w ?1)
  				       (make-string (- w half-w) ?0)))
  			     2))
  	nil nil 'center)))
  
  (advice-add #'diff-hl-define-bitmaps
  	      :after #'dysthesis/pretty-diff-hl-fringe)
  
  (defun dysthesis/diff-hl-type-at-pos-fn (type _pos)
    'diff-hl-bmp-middle)
  
  (setq diff-hl-fringe-bmp-function #'dysthesis/diff-hl-type-at-pos-fn)
  (defun dysthesis/diff-hl-fringe-pretty(_)
    (set-face-attribute 'diff-hl-insert nil :background 'unspecified :inherit nil)
    (set-face-attribute 'diff-hl-delete nil :background 'unspecified :inherit nil)
    (set-face-attribute 'diff-hl-change nil :background 'unspecified :inherit nil))
  (add-to-list 'after-make-frame-functions
  	       #'dysthesis/diff-hl-fringe-pretty)
  (add-to-list 'enable-theme-functions #'dysthesis/diff-hl-fringe-pretty)
  (add-hook 'magit-post-refresh-hook 'diff-hl-magit-post-refresh))

(use-package forge
  :ensure t
  :defer
  :after magit
  :init
  (setq forge-add-default-bindings nil)
  (with-eval-after-load 'ghub-graphql
    (setq ghub-graphql-message-progress t))
  :config
  (setq auth-sources '("~/.authinfo.gpg"))
  (setq forge-bug-reference-remote-files nil
        forge-database-file
        (file-name-concat user-cache-directory "forge" "forge-database.sqlite"))

  (with-eval-after-load 'forge-topics
    (define-key forge-topics-mode-map (kbd "q") #'kill-current-buffer))

  (define-key magit-mode-map [remap magit-browse-thing] #'forge-browse)
  (define-key magit-remote-section-map [remap magit-browse-thing]
	      #'forge-browse-remote)
  (define-key magit-branch-section-map [remap magit-browse-thing]
	      #'forge-browse-branch)

  (add-to-list 'display-buffer-alist
	       '("^\\*?[0-9]+:\\(?:new-\\|[0-9]+$\\)"
                 (display-buffer-reuse-window display-buffer-below-selected)
                 (window-height . 0.45))))

(use-package magit-todos
  :ensure t
  :after magit
  :config (magit-todos-mode 1))

(use-package git-commit
  :ensure t
  :after magit
  :config
  (global-git-commit-mode 1)
  (setq git-commit-summary-max-length 50
        git-commit-style-convention-checks
        '(overlong-summary-line non-empty-second-line))
  (add-hook 'git-commit-mode-hook
            (lambda ()
	      (setq-local fill-column 72)))
  (add-hook 'git-commit-setup-hook
            #'euler/git-commit-start-in-insert-state-maybe))

(with-eval-after-load 'evil-collection-magit
  (evil-define-key* 'normal magit-status-mode-map [escape] nil)
  (evil-define-key* '(normal visual) magit-mode-map
    "*" #'magit-worktree
    "zt" #'evil-scroll-line-to-top
    "zz" #'evil-scroll-line-to-center
    "zb" #'evil-scroll-line-to-bottom
    "g=" #'magit-diff-default-context
    "gi" #'forge-jump-to-issues
    "gm" #'forge-jump-to-pullreqs)

  (general-define-key
   :states '(normal visual)
   :keymaps 'magit-mode-map
   "q" #'euler/magit-quit
   "Q" #'euler/magit-quit-all
   "]" #'magit-section-forward-sibling
   "[" #'magit-section-backward-sibling
   "gr" #'magit-refresh
   "gR" #'magit-refresh-all)
  (general-define-key
   :states '(normal visual)
   :keymaps 'magit-status-mode-map
   "gz" #'magit-refresh)
  (general-define-key
   :states '(normal visual)
   :keymaps 'magit-diff-mode-map
   "gd" #'magit-jump-to-diffstat-or-diff)
  (general-define-key
   :states '(normal visual)
   :keymaps 'magit-process-mode-map
   "`" #'ignore)
  (general-define-key
   :states 'normal
   :keymaps '(magit-status-mode-map
	      magit-stash-mode-map
	      magit-revision-mode-map
	      magit-process-mode-map
	      magit-diff-mode-map)
   "TAB" #'magit-section-toggle)

  (with-eval-after-load 'git-rebase
    (dolist (key '(("M-k" . "gk") ("M-j" . "gj")))
      (let ((desc (assoc (car key)
                         evil-collection-magit-rebase-commands-w-descriptions)))
        (when desc
          (setcar desc (cdr key)))))
    (evil-define-key* evil-collection-magit-state git-rebase-mode-map
      "gj" #'git-rebase-move-line-down
      "gk" #'git-rebase-move-line-up)))

(with-eval-after-load 'evil-collection-magit-section
  (dolist (key '("M-1" "M-2" "M-3" "M-4" "1" "2" "3" "4" "0"))
    (define-key magit-section-mode-map (kbd key) nil)))

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
                 (repeat :tag "Disabled modes" symbol)))

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
  (or (euler/some (lambda (file)
                    (locate-dominating-file default-directory file))
                  euler/format--prettier-config-files)
      (euler/format--prettier-package-json-p)))

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
  (define-key apheleia-mode-map [remap save-buffer] #'euler/format-save-buffer)
  (define-key apheleia-mode-map [remap basic-save-buffer] #'euler/format-save-buffer)

  (add-hook 'hack-local-variables-hook #'euler/format-refresh-after-local-vars)

  (euler/format--set-formatter 'eglot #'euler/format-eglot-buffer)

  (dolist (entry '((sh-mode . shfmt)
                   (cuda-mode . clang-format)
                   (cuda-ts-mode . clang-format)
                   (protobuf-mode . clang-format)))
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

(defvar euler-tool-bin-directories
  (delete-dups
   (delq nil
         (mapcar (lambda (program)
                   (let ((path (executable-find program)))
                     (when path
		       (directory-file-name (file-name-directory path)))))
                 '("emacs-lsp-booster"
                   "ls"
                   "gls"
                   "rsync"
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
                 (not (euler/string-empty-p dir))
                 (not (member dir merged)))
        (push dir merged)))
    (setq merged (nreverse merged))
    (setenv "PATH" (euler/string-join merged path-separator))
    (setq-local exec-path (append merged (and (memq nil exec-path) '(nil))))))

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

(defvar euler/lsp--default-read-process-output-max nil
  "Saved `read-process-output-max' before LSP optimisation.")

(defvar euler/lsp--default-gc-cons-threshold nil
  "Saved `gc-cons-threshold' before LSP optimisation.")

(defvar euler/lsp--optimisation-init-p nil
  "Non-nil when LSP optimisation defaults have been saved.")

(defvar euler/lsp--deferred-shutdown-timers (make-hash-table :test #'eq)
  "Deferred Eglot shutdown timers by server.")

(defvar euler/lsp-optimisation-mode-map (make-sparse-keymap)
  "Keymap for `euler/lsp-optimisation-mode'.")

(define-minor-mode euler/lsp-optimisation-mode
  "Apply global GC and process I/O tuning while LSP servers are active."
  :group 'euler/lsp
  :global t
  :init-value nil
  (if euler/lsp-optimisation-mode
      (unless euler/lsp--optimisation-init-p
        (setq euler/lsp--default-read-process-output-max
	      (default-value 'read-process-output-max))
        (setq euler/lsp--default-gc-cons-threshold gc-cons-threshold)
        (setq-default read-process-output-max (* 4 1024 1024))
        (unless (fboundp 'igc-info)
          (setq gc-cons-threshold (* 64 1024 1024)))
        (setq euler/lsp--optimisation-init-p t))
    (when euler/lsp--optimisation-init-p
      (setq-default read-process-output-max
                    euler/lsp--default-read-process-output-max)
      (unless (fboundp 'igc-info)
        (setq gc-cons-threshold euler/lsp--default-gc-cons-threshold))
      (setq euler/lsp--optimisation-init-p nil))))

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

(use-package eglot
  :hook
  ((nix-mode . eglot-ensure))
  :init
  (setq eglot-sync-connect 1
        eglot-autoshutdown t
        eglot-stay-out-of
        (cons 'company
	      (remq 'company
                    (ensure-list (and (boundp 'eglot-stay-out-of)
				      eglot-stay-out-of)))))
  :custom
  (eglot-send-changes-idle-time 0.1)
  (eglot-extend-to-xref t)
  :config
  (when (boundp 'eglot-auto-display-help-buffer)
    (setq eglot-auto-display-help-buffer nil))
  (when (boundp 'eglot-code-action-indications)
    (setq eglot-code-action-indications '(eldoc-hint)))
  (when (boundp 'eglot-events-buffer-config)
    (setq eglot-events-buffer-config
          (plist-put eglot-events-buffer-config :size 0)))

  (dysthesis/start/leader-keys
    "c" '(:ignore t :which-key "Code")
    "c <escape>" '(keyboard-escape-quit :which-key t)
    "c r" '(eglot-rename :which-key "Rename")
    "c a" '(eglot-code-actions :which-key "Actions")
    "c h" '(euler/eglot-lookup-documentation :which-key "Docs"))

  (add-hook 'eglot-managed-mode-hook #'euler/lsp-sync-optimisation-mode)
  (advice-add 'eglot--managed-mode :around #'euler/lsp-defer-eglot-shutdown-a)

  ;; Sometimes you need to tell Eglot where to find the language server
  (dolist (mode '(c-mode c-ts-mode c++-mode c++-ts-mode))
    (euler/eglot-set-server
     mode `("clangd" ,(format "-j=%d" (max 1 (/ (num-processors) 2))))))
  (euler/eglot-set-server 'nix-mode '("nil"))
  (euler/eglot-set-server
   '((rustic-mode :language-id "rust") rust-mode rust-ts-mode)
   '("rust-analyzer")))



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
  (with-eval-after-load 'eglot
    (define-key eglot-mode-map [remap xref-find-apropos] #'consult-eglot-symbols))
  (dysthesis/start/leader-keys
    "c j" '(consult-eglot-symbols :which-key "Symbols")))

(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'"
  :hook (nix-mode . eglot-ensure))

(use-package nix-ts-mode
  :ensure t
  :mode "\\.nix\\'")

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

(declare-function treesit-fold--create-overlay "treesit-fold" (range))
(declare-function treesit-fold--get-fold-range "treesit-fold" (node))
(declare-function treesit-fold-parsers-zig "treesit-fold-parsers" ())
(declare-function treesit-fold-ready-p "treesit-fold")
(declare-function treesit-buffer-root-node "treesit")
(declare-function treesit-node-language "treesit" (node))
(declare-function treesit-node-parent "treesit" (node))
(declare-function treesit-node-start "treesit" (node))
(declare-function treesit-node-end "treesit" (node))
(declare-function treesit-query-capture "treesit" (node query &optional beg end node-only))
(declare-function treesit-query-compile "treesit" (language query &optional eager))

(defvar treesit-fold-mode)
(defvar treesit-fold-on-fold-hook)
(defvar treesit-fold-range-alist)

(defvar-local euler/treesit-fold-bodies-initialized nil
  "Non-nil means this buffer already got its initial body folds.")

(defvar euler/treesit-fold--body-query-cache (make-hash-table :test 'equal)
  "Compiled Tree-sitter queries for folding function bodies.")

(defvar euler/treesit-fold-body-rules
  '((:name c-family
	   :modes (c-mode c-ts-mode c++-mode c++-ts-mode)
	   :query "((function_definition body: (compound_statement) @body))")
    (:name emacs-lisp
	   :modes (emacs-lisp-mode)
	   :query "[(function_definition) (macro_definition)] @fold")
    (:name go
	   :modes (go-mode go-ts-mode)
	   :query "[(function_declaration body: (block) @body)
               (method_declaration body: (block) @body)
               (func_literal body: (block) @body)]")
    (:name javascript
	   :modes (js-mode js-ts-mode typescript-mode typescript-ts-mode tsx-ts-mode)
	   :query "[(function_declaration body: (statement_block) @body)
               (function_expression body: (statement_block) @body)
               (arrow_function body: (statement_block) @body)
               (method_definition body: (statement_block) @body)]")
    (:name python
	   :modes (python-mode python-ts-mode)
	   :query "((function_definition) @fold)")
    (:name rust
	   :modes (rust-mode rust-ts-mode rustic-mode)
	   :query "((function_item body: (block) @body))")
    (:name zig
	   :modes (zig-mode zig-ts-mode)
	   :query "((Decl (FnProto) (Block) @body))"))
  "Rules for auto-folding function and method bodies.

Each rule is a plist with:
- :name, a unique symbol used by `euler/treesit-fold-add-body-rule'.
- :modes, major modes where the rule applies.
- :query, a Tree-sitter query that captures @body or @fold.

Capture @body when the captured node is the body block.  Capture @fold when the
captured node is the whole function-like node and `treesit-fold' already knows
how to derive its fold range.")

;; (euler/treesit-fold-add-body-rule :: (function (symbol mixed string) mixed))
(defun euler/treesit-fold-add-body-rule (name modes query)
  "Register body-fold QUERY named NAME for MODES.

QUERY should capture @body for body nodes or @fold for whole function nodes.
Rules added later win because lookup uses the first matching rule."
  (let ((rule (list :name name
                    :modes (if (listp modes) modes (list modes))
                    :query query)))
    (add-to-list 'euler/treesit-fold-body-rules rule)
    rule))

;; (euler/treesit-fold--body-rule :: (function (symbol) mixed))
(defun euler/treesit-fold--body-rule (&optional mode)
  "Return body-fold rule for MODE."
  (let ((mode (or mode major-mode)))
    (euler/find-if
     (lambda (rule)
       (memq mode (plist-get rule :modes)))
     euler/treesit-fold-body-rules)))

;; (euler/treesit-fold--body-query :: (function (mixed string) mixed))
(defun euler/treesit-fold--body-query (language query)
  "Return compiled QUERY for LANGUAGE."
  (let ((key (cons language query)))
    (or (gethash key euler/treesit-fold--body-query-cache)
        (puthash key
                 (treesit-query-compile language query)
                 euler/treesit-fold--body-query-cache))))

;; (euler/treesit-fold--range-valid-p :: (function (mixed) bool))
(defun euler/treesit-fold--range-valid-p (range)
  "Return non-nil when RANGE can be folded."
  (and (consp range)
       (integer-or-marker-p (car range)) ; elsa-disable-line
       (integer-or-marker-p (cdr range)) ; elsa-disable-line
       (< (car range) (cdr range)) ; elsa-disable-line
       (/= (line-number-at-pos (car range) t) ; elsa-disable-line
           (line-number-at-pos (cdr range) t)))) ; elsa-disable-line

;; (euler/treesit-fold--fold-range-for-capture :: (function (mixed mixed) mixed))
(defun euler/treesit-fold--fold-range-for-capture (capture node)
  "Return fold range for CAPTURE on NODE."
  (pcase capture
    ((or 'body 'fold) (treesit-fold--get-fold-range node))))

;; (euler/treesit-fold--target-node-for-capture :: (function (mixed mixed) mixed))
(defun euler/treesit-fold--target-node-for-capture (capture node)
  "Return the syntax node used as jump target for CAPTURE on NODE."
  (pcase capture
    ('body (or (treesit-node-parent node) node))
    ('fold node)))

;; (euler/treesit-fold--body-candidates :: (function () mixed))
(defun euler/treesit-fold--body-candidates ()
  "Return body fold candidates for the current buffer.
Each candidate is (TARGET-RANGE . FOLD-RANGE)."
  (let* ((rule (euler/treesit-fold--body-rule))
         (query-text (and rule (plist-get rule :query))))
    (when (and query-text
	       (treesit-fold-ready-p))
      (let* ((root (treesit-buffer-root-node))
             (language (and root (treesit-node-language root)))
             (query (and language
                         (euler/treesit-fold--body-query language query-text))))
        (when query
          (condition-case nil
	      (let (candidates)
                (dolist (capture (treesit-query-capture root query) (nreverse candidates))
                  (let* ((capture-name (car capture))
                         (node (cdr capture))
                         (target (euler/treesit-fold--target-node-for-capture
                                  capture-name node))
                         (target-range (and target
                                            (cons (treesit-node-start target)
                                                  (treesit-node-end target))))
                         (fold-range (euler/treesit-fold--fold-range-for-capture
				      capture-name node)))
                    (when (and target-range
			       (euler/treesit-fold--range-valid-p fold-range))
		      (push (cons target-range fold-range) candidates)))))
            (treesit-query-error nil)))))))

;; (euler/treesit-fold--overlay-at-range-p :: (function (mixed) bool))
(defun euler/treesit-fold--overlay-at-range-p (range) ; elsa-disable-line
  "Return non-nil if a `treesit-fold' overlay already covers RANGE."
  (euler/some
   (lambda (ov)
     (and (eq (overlay-get ov 'creator) 'treesit-fold)
          (= (overlay-start ov) (car range))
          (= (overlay-end ov) (cdr range))))
   (overlays-in (car range) (cdr range))))

;; (euler/treesit-fold--delete-overlays-at-range :: (function (mixed) bool))
(defun euler/treesit-fold--delete-overlays-at-range (range)
  "Delete `treesit-fold' overlays that exactly cover RANGE."
  (let (deleted)
    (dolist (ov (overlays-in (car range) (cdr range)))
      (when (and (eq (overlay-get ov 'creator) 'treesit-fold)
                 (= (overlay-start ov) (car range))
                 (= (overlay-end ov) (cdr range)))
        (delete-overlay ov)
        (setq deleted t)))
    deleted))

;; (euler/treesit-fold-close-function-bodies :: (function () mixed))
(defun euler/treesit-fold-close-function-bodies ()
  "Fold all function and method bodies in the current buffer."
  (interactive)
  (when (bound-and-true-p treesit-fold-mode)
    (let (folded)
      (dolist (candidate (euler/treesit-fold--body-candidates))
        (let ((range (cdr candidate)))
          (unless (euler/treesit-fold--overlay-at-range-p range)
            (when (treesit-fold--create-overlay range)
	      (setq folded t)))))
      (when folded
        (run-hooks 'treesit-fold-on-fold-hook))
      folded)))

;; (euler/treesit-fold-close-function-bodies-once :: (function () mixed))
(defun euler/treesit-fold-close-function-bodies-once ()
  "Fold function bodies once when `treesit-fold-mode' first starts."
  (when (and treesit-fold-mode
             (not euler/treesit-fold-bodies-initialized))
    (setq-local euler/treesit-fold-bodies-initialized t)
    (euler/treesit-fold-close-function-bodies)))

;; (euler/treesit-fold--candidate-at-point-p :: (function (mixed int) bool))
(defun euler/treesit-fold--candidate-at-point-p (candidate point)
  "Return non-nil when CANDIDATE is a good fold to open for POINT."
  (let* ((target (car candidate))
         (range (cdr candidate))
         (line (line-number-at-pos point t)))
    (or (<= (car target) point (cdr target))
        (= line (line-number-at-pos (car target) t))
        (= line (line-number-at-pos (car range) t)))))

;; (euler/treesit-fold-open-at-point :: (function () mixed))
(defun euler/treesit-fold-open-at-point ()
  "Open the folded function body that contains or follows point."
  (when (bound-and-true-p treesit-fold-mode)
    (let ((candidate (euler/find-if
		      (lambda (candidate)
                        (euler/treesit-fold--candidate-at-point-p
                         candidate (point)))
		      (euler/treesit-fold--body-candidates))))
      (when candidate
        (let ((range (cdr candidate)))
          (when range
            (when (euler/treesit-fold--delete-overlays-at-range range)
	      (run-hooks 'treesit-fold-on-fold-hook))))))))

(use-package treesit-fold
  :ensure t
  :config
  (setq treesit-fold-line-count-show t)  ; Show line count in folded regions
  (setq treesit-fold-line-count-format " ⋯ %d lines ⋯ ")
  (unless (alist-get 'zig-ts-mode treesit-fold-range-alist)
    (add-to-list 'treesit-fold-range-alist
                 (cons 'zig-ts-mode (treesit-fold-parsers-zig))))
  (add-hook 'treesit-fold-mode-hook
            #'euler/treesit-fold-close-function-bodies-once)
  (add-hook 'xref-after-jump-hook #'euler/treesit-fold-open-at-point)
  (add-hook 'xref-after-return-hook #'euler/treesit-fold-open-at-point)
  (global-treesit-fold-mode)
  ;; TODO: DWIM keybind to use <TAB> to toggle folding where applicable
  (dysthesis/start/leader-keys
    "c f" '(treesit-fold-toggle :wk "[C]ode [F]old")
    "c F" '(euler/treesit-fold-close-function-bodies :wk "[C]ode [F]old bodies")))

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
