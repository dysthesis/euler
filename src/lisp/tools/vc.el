;;; -*- lexical-binding: t; -*-
(require 'core/lib)
(require 'ui/keys)

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

(provide 'tools/vc)
