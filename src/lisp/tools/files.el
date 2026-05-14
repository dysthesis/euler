;;; -*- lexical-binding: t; -*-
(require 'core/lib)
(require 'ui/keys)

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

(provide 'tools/files)
