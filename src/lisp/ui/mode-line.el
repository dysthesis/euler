;;; -*- lexical-binding: t; -*-
(require 'core/lib)

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

(defvar euler-mode-line-icons-enabled nil
  "Non-nil when Nerd Icons can be used in the Euler mode line.")

(defvar euler-mode-line--mode-icon-cache (make-hash-table :test 'eq)
  "Cached mode icons by major mode.")

(defvar euler-mode-line--octicon-cache (make-hash-table :test 'equal)
  "Cached octicons by name.")

(defvar euler-mode-line--codicon-cache (make-hash-table :test 'equal)
  "Cached codicons by name.")

(defvar-local euler-mode-line--buffer-info-cache nil
  "Cached buffer/project display data for the Euler mode line.")

(defvar-local euler-mode-line--project-cache nil
  "Cached project data for the Euler mode line.")

(defvar-local euler-mode-line--vc-cache nil
  "Cached VC branch segment for the Euler mode line.")

(defvar-local euler-mode-line--position-cache nil
  "Cached cursor position segment for the Euler mode line.")

(defvar-local euler-mode-line--render-cache nil
  "Cached complete Euler mode line for stable redisplays.")

(defun euler/mode-line-enable-icons-maybe ()
  "Enable Nerd Icons in the mode line if the package is available."
  (when (require 'nerd-icons nil t)
    (setq euler-mode-line-icons-enabled t)
    (clrhash euler-mode-line--mode-icon-cache)
    (clrhash euler-mode-line--octicon-cache)
    (clrhash euler-mode-line--codicon-cache)
    (force-mode-line-update t)))

(add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-idle-timer 2 nil #'euler/mode-line-enable-icons-maybe)))

(defun euler/mode-line--truncate-left (text max-width)
  "Return TEXT shortened from the left to MAX-WIDTH characters."
  (let ((max-width (max 4 max-width)))
    (if (<= (length text) max-width)
        text
      (concat "..." (substring text (- (length text) (- max-width 3)))))))

(defun euler/mode-line--join (items)
  "Join non-empty ITEMS with a muted separator."
  (mapconcat #'identity
             (delq nil
                   (mapcar (lambda (item)
                             (when (and item (not (euler/string-empty-p item)))
                               item))
                           items))
             (euler/mode-line--sep)))

(defun euler/mode-line--sep ()
  (propertize " · " 'face 'euler-mode-line-muted))

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

(defun euler/mode-line--cached-icon (cache key producer fallback)
  "Return cached icon for KEY in CACHE, or FALLBACK."
  (or (gethash key cache)
      (puthash key
               (euler/mode-line--icon
                (and euler-mode-line-icons-enabled
                     (ignore-errors (funcall producer)))
                fallback)
               cache)))

(defun euler/mode-line--mode-icon ()
  "Return icon for the current major mode."
  (euler/mode-line--cached-icon
   euler-mode-line--mode-icon-cache
   major-mode
   (lambda () (nerd-icons-icon-for-mode major-mode))
   ":"))

(defun euler/mode-line--octicon (name fallback)
  "Return octicon NAME or FALLBACK."
  (euler/mode-line--cached-icon
   euler-mode-line--octicon-cache
   name
   (lambda () (nerd-icons-octicon name))
   fallback))

(defun euler/mode-line--codicon (name fallback)
  "Return codicon NAME or FALLBACK."
  (euler/mode-line--cached-icon
   euler-mode-line--codicon-cache
   name
   (lambda () (nerd-icons-codicon name))
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

(defun euler/mode-line--project ()
  "Return cached project object and root for the current buffer."
  (let ((key (list (buffer-file-name) default-directory)))
    (if (equal key (car euler-mode-line--project-cache))
        (cdr euler-mode-line--project-cache)
      (let* ((project (project-current nil))
             (root (when project (expand-file-name (project-root project))))
             (data (list :project project :root root)))
        (setq euler-mode-line--project-cache (cons key data))
        data))))

(defun euler/mode-line--buffer-info (project-data)
  "Return cached buffer display metadata for PROJECT-DATA."
  (let* ((file (buffer-file-name))
         (project (plist-get project-data :project))
         (root (plist-get project-data :root))
         (key (list file (buffer-name) root)))
    (if (equal key (car euler-mode-line--buffer-info-cache))
        (cdr euler-mode-line--buffer-info-cache)
      (let* ((inside-project (and file root (file-in-directory-p file root)))
             (name (cond
                    (inside-project
                     (file-relative-name file root))
                    (file
                     (abbreviate-file-name file))
                    (t
                     (buffer-name))))
             (project-name
              (when (and project root (not inside-project))
                (file-name-nondirectory (directory-file-name root))))
             (info (list :name name
                         :help (or file name)
                         :project-name project-name)))
        (setq euler-mode-line--buffer-info-cache (cons key info))
        info))))

(defun euler/mode-line-buffer-name (project-data)
  "Return compact buffer name, relative to PROJECT when possible."
  (let* ((info (euler/mode-line--buffer-info project-data))
         (name (plist-get info :name))
         (limit (max 20 (/ (window-total-width) 2))))
    (propertize
     (euler/mode-line--truncate-left name limit)
     'face 'euler-mode-line-buffer
     'help-echo (plist-get info :help))))

(defun euler/mode-line-buffer-status ()
  "Return modified/read-only buffer flags."
  (euler/mode-line--join
   (list
    (when buffer-read-only
      (propertize "RO" 'face 'euler-mode-line-read-only))
    (when (buffer-modified-p)
      (propertize "󰆓 " 'face 'euler-mode-line-modified)))))


(defun euler/mode-line-project-name (project-data)
  "Return current project name."
  (when-let ((name (plist-get (euler/mode-line--buffer-info project-data)
                              :project-name)))
    (propertize name 'face 'euler-mode-line-muted)))

(defun euler/mode-line-vc-branch ()
  "Return compact VC branch name."
  (let ((key vc-mode))
    (if (equal key (car euler-mode-line--vc-cache))
        (cdr euler-mode-line--vc-cache)
      (let ((value
             (when vc-mode
               (let* ((text (euler/string-trim vc-mode))
                      (branch (replace-regexp-in-string
                               "\\`[[:alpha:]]+[:-]" "" text)))
                 (unless (euler/string-empty-p branch)
                   (euler/mode-line--pair
                    (euler/mode-line--octicon "nf-oct-git_branch" "git")
                    (propertize branch 'face 'euler-mode-line-branch)))))))
        (setq euler-mode-line--vc-cache (cons key value))
        value))))

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
  (let ((key (list (point) (buffer-chars-modified-tick)
                   euler-mode-line-icons-enabled)))
    (if (equal key (car euler-mode-line--position-cache))
        (cdr euler-mode-line--position-cache)
      (let ((value
             (euler/mode-line--pair
              (euler/mode-line--codicon "nf-cod-location" "@")
              (propertize
               (format "%d:%d" (line-number-at-pos nil t) (current-column))
	       'face 'euler-mode-line-position))))
        (setq euler-mode-line--position-cache (cons key value))
        value))))

(defun euler/mode-line-render (left right)
  "Render LEFT and RIGHT mode line segments."
  (let ((spacer-width (max 1 (- (window-total-width)
                                (string-width left)
                                (string-width right)
                                2))))
    (concat " " left (make-string spacer-width ?\s) right " ")))

(defun euler/mode-line ()
  "Return the Euler mode line."
  (let ((key (list (window-total-width)
                   (buffer-name)
                   (buffer-file-name)
                   default-directory
                   (buffer-modified-p)
                   buffer-read-only
                   (point)
                   (buffer-chars-modified-tick)
                   major-mode
                   vc-mode
                   (and (boundp 'evil-state) evil-state)
                   (and (boundp 'evil-visual-selection)
                        evil-visual-selection)
                   euler-mode-line-icons-enabled)))
    (if (equal key (car euler-mode-line--render-cache))
        (cdr euler-mode-line--render-cache)
      (let* ((project-data (euler/mode-line--project))
             (value
              (euler/mode-line-render
               (euler/mode-line--join
                (list
                 (euler/mode-line-evil-state)
                 (euler/mode-line-buffer-name project-data)
                 (euler/mode-line-buffer-status)))
               (euler/mode-line--join
                (list
                 (euler/mode-line-project-name project-data)
                 (euler/mode-line-vc-branch)
                 (euler/mode-line-major-mode)
                 (euler/mode-line-position))))))
        (setq euler-mode-line--render-cache (cons key value))
        value))))

(setq-default mode-line-format '((:eval (euler/mode-line))))

(provide 'ui/mode-line)
