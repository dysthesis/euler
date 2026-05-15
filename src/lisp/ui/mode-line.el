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

(defvar euler-mode-line-icons-enabled (require 'nerd-icons nil t)
  "Non-nil when Nerd Icons can be used in the Euler mode line.")

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
      (propertize "󰆓 " 'face 'euler-mode-line-modified)))))

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

(provide 'ui/mode-line)
