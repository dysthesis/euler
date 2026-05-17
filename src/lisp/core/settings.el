;;; -*- lexical-binding: t; -*-
(require 'core/lib)

(setq use-package-always-ensure nil
      use-package-ensure-function 'ignore)
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
  (setq window-sides-vertical t) ;; Left and right side windows occupy full frame height
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

(provide 'core/settings)
