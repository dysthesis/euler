(use-package emacs
        :demand t
        :ensure nil
        :init
				(load-theme 'modus-vivendi t)
        (scroll-bar-mode -1)        ; Disable visible scrollbar
        (tool-bar-mode -1)          ; Disable the toolbar
        (tooltip-mode -1)           ; Disable tooltips
        (set-fringe-mode 10)        ; Give some breathing room
        (menu-bar-mode -1)          ; Disable the menu bar
        (let* ((font-size
                (let* ((hostname (car (split-string (system-name) "\\." t)))
                       (size-by-hostname '(("deimos" . 9)
                			     ("phobos" . 13)))
                       (default-size 9))
                  (or (cdr (assoc hostname size-by-hostname))
                      default-size)))
              (font-height (* font-size 10)))
          (set-face-attribute 'default nil :font "JBMono Nerd Font" :height font-height)
          (set-fontset-font t nil (font-spec :size font-size :name "JBMono Nerd Font"))
          (setq-default line-spacing 0.2)
          (custom-theme-set-faces
           'user
           `(variable-pitch ((t (:family "Atkinson Hyperlegible Next" :height ,font-height))))
           `(fixed-pitch ((t (:family "JBMono Nerd Font" :height ,font-height))))))
        (add-to-list 'face-font-rescale-alist '("Atkinson Hyperlegible Next" . 1.2))
        (setopt inhibit-splash-screen t)
        (setopt initial-major-mode 'fundamental-mode)
        (setopt display-time-default-load-average nil)
        (setopt auto-revert-avoid-polling t)
        (setopt auto-revert-interval 5)
        (setopt auto-revert-check-vc-info t)
        (global-auto-revert-mode)
        (setopt savehist-additional-variables
                '(search-ring regexp-search-ring kill-ring))
        (add-hook 'savehist-save-hook
                  (lambda ()
                    (setq kill-ring
                          (delq nil
                                (mapcar (lambda (entry)
                                          (when (stringp entry)
                                            (substring-no-properties entry)))
                                        kill-ring)))))
        (savehist-mode)
        (save-place-mode 1)
        (advice-add 'save-place-find-file-hook :after
                    (lambda (&rest _)
                      (when buffer-file-name
                        (ignore-errors (recenter)))))
        (windmove-default-keybindings 'control)
        (setopt window-combination-resize t)
        (winner-mode +1)
        (defun dysthesis/toggle-delete-other-windows ()
          "Delete other windows, or restore the previous window configuration."
          (interactive)
          (if (and winner-mode
                   (equal (selected-window) (next-window)))
              (winner-undo)
            (delete-other-windows)))
        (keymap-global-set "C-x 1" #'dysthesis/toggle-delete-other-windows)
        (setopt sentence-end-double-space nil)
        (setopt save-interprogram-paste-before-kill t)
        (setopt kill-do-not-save-duplicates t)
        (setopt set-mark-command-repeat-pop t)
        ;; Make right-click do something sensible
        (when (display-graphic-p)
          (context-menu-mode))
        (defun dysthesis/backup-file-name (fpath)
          "Return a new file path of a given file path.
        If the new path's directories does not exist, create them."
          (let* ((backupRootDir "~/.config/emacs/emacs-backup/")
                 (filePath (replace-regexp-in-string "[A-Za-z]:" "" fpath )) ; remove Windows driver letter in path
                 (backupFilePath (replace-regexp-in-string "//" "/" (concat backupRootDir filePath "~") )))
            (make-directory (file-name-directory backupFilePath) (file-name-directory backupFilePath))
            backupFilePath))
        (setopt make-backup-file-name-function 'dysthesis/backup-file-name)
        (setopt enable-recursive-minibuffers t)                ; Use the minibuffer whilst in the minibuffer
        (setopt completion-cycle-threshold 1)                  ; TAB cycles candidates
        (setopt completions-detailed t)                        ; Show annotations
        (setopt tab-always-indent 'complete)                   ; When I hit TAB, try to complete, otherwise, indent
        (setopt completion-styles '(basic initials substring)) ; Different styles to match input to candidates

        (setopt completion-auto-help 'always)                  ; Open completion always; `lazy' another option
        (setopt completions-max-height 20)                     ; This is arbitrary
        (setopt completions-detailed t)
        (setopt completions-format 'one-column)
        (setopt completions-group t)
        (setopt completion-auto-select 'second-tab)            ; Much more eager
        ;(setopt completion-auto-select t)                     ; See `C-h v completion-auto-select' for more possible values
        (setq ffap-machine-p-known 'reject)                    ; Avoid network pings from `find-file-at-point'

        (keymap-set minibuffer-mode-map "TAB" 'minibuffer-complete) ; TAB acts more like how it does in the shell

        ;; For a fancier built-in completion option, try ido-mode,
        ;; icomplete-vertical, or fido-mode. See also the file extras/base.el

        ;(icomplete-vertical-mode)
        ;(fido-vertical-mode)
        ;(setopt icomplete-delay-completions-threshold 4000)
        ;; Mode line information
        (setopt line-number-mode t)                        ; Show current line in modeline
        (setq display-line-numbers-type 'relative)
        (setopt column-number-mode t)                      ; Show column as well

        (setopt x-underline-at-descent-line nil)           ; Prettier underlines
        (setopt switch-to-buffer-obey-display-actions t)   ; Make switching buffers more consistent

        (setopt show-trailing-whitespace nil)      ; By default, don't underline trailing spaces
        (setopt indicate-buffer-boundaries 'left)  ; Show buffer top and bottom in the margin

        ;; Enable horizontal scrolling
        (setopt mouse-wheel-tilt-scroll t)
        (setopt mouse-wheel-flip-direction t)

        ;; We won't set these, but they're good to know about
        ;;
        ;; (setopt indent-tabs-mode nil)
        ;; (setopt tab-width 4)

        ;; Misc. UI tweaks
        (setopt redisplay-skip-fontification-on-input t)
        (setq-default cursor-in-non-selected-windows nil)
        (setopt highlight-nonselected-windows nil)
        (setopt help-window-select t)
        (blink-cursor-mode -1)                                ; Steady cursor
        (pixel-scroll-precision-mode)                         ; Smooth scrolling

        ;; Use common keystrokes by default
        (cua-mode)

        ;; Display line numbers in programming mode
        (add-hook 'prog-mode-hook 'display-line-numbers-mode)
        (setopt display-line-numbers-width 3)           ; Set a minimum width

        ;; Nice line wrapping when working with text
        (add-hook 'text-mode-hook 'visual-line-mode)

        ;; Modes to highlight the current line with
        (let ((hl-line-hooks '(text-mode-hook prog-mode-hook)))
          (mapc (lambda (hook) (add-hook hook 'hl-line-mode)) hl-line-hooks))
        ;; Show the tab-bar as soon as tab-bar functions are invoked
        (setopt tab-bar-show 1)

        ;; Add the time to the tab-bar, if visible
        (add-to-list 'tab-bar-format 'tab-bar-format-align-right 'append)
        (add-to-list 'tab-bar-format 'tab-bar-format-global 'append)
        (setopt display-time-format "%a %F %T")
        (setopt display-time-interval 1)
        (display-time-mode))
