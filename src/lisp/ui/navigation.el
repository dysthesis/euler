;;; -*- lexical-binding: t; -*-
(require 'ui/keys)

(defcustom euler/window-resize-step 3
  "Columns or lines to resize windows per smart-splits keypress."
  :type 'integer
  :group 'euler)

(defun euler/resize-window--amount (count)
  "Return resize amount for prefix COUNT."
  (* euler/window-resize-step (prefix-numeric-value (or count 1))))

(defun euler/resize-window--neighbor (direction window sign)
  "Return WINDOW neighbour in DIRECTION using edge SIGN."
  (window-in-direction direction window nil sign nil 'ignore-minibuffer))

(defun euler/resize-window--adjust (window delta &optional horizontal)
  "Move WINDOW trailing edge by DELTA. HORIZONTAL moves right edge."
  (when (window-live-p window)
    (condition-case nil
        (progn
          (adjust-window-trailing-edge window delta horizontal)
          t)
      (error nil))))

(defun euler/resize-window--move-edge (direction count)
  "Move selected window edge in DIRECTION by COUNT resize steps."
  (let* ((window (selected-window))
         (amount (euler/resize-window--amount count)))
    (pcase direction
      ('left
       (if-let ((left (euler/resize-window--neighbor 'left window 1)))
           (euler/resize-window--adjust left (- amount) t)
         (euler/resize-window--adjust window (- amount) t)))
      ('right
       (if (euler/resize-window--neighbor 'right window -1)
           (euler/resize-window--adjust window amount t)
         (when-let ((left (euler/resize-window--neighbor 'left window 1)))
           (euler/resize-window--adjust left amount t))))
      ('up
       (if-let ((above (euler/resize-window--neighbor 'above window 1)))
           (euler/resize-window--adjust above (- amount))
         (euler/resize-window--adjust window (- amount))))
      ('down
       (if (euler/resize-window--neighbor 'below window -1)
           (euler/resize-window--adjust window amount)
         (when-let ((above (euler/resize-window--neighbor 'above window 1)))
           (euler/resize-window--adjust above amount)))))))

(defun euler/resize-window-left (&optional count)
  "Resize current window left by COUNT smart-splits steps."
  (interactive "p")
  (euler/resize-window--move-edge 'left count))

(defun euler/resize-window-down (&optional count)
  "Resize current window down by COUNT smart-splits steps."
  (interactive "p")
  (euler/resize-window--move-edge 'down count))

(defun euler/resize-window-up (&optional count)
  "Resize current window up by COUNT smart-splits steps."
  (interactive "p")
  (euler/resize-window--move-edge 'up count))

(defun euler/resize-window-right (&optional count)
  "Resize current window right by COUNT smart-splits steps."
  (interactive "p")
  (euler/resize-window--move-edge 'right count))

(use-package evil
  :ensure t
  :init
  (setq evil-want-integration t) ;; This is optional since it's already set to t by default.
  (setq evil-want-keybinding nil)
  :config
  (evil-mode 1)
  (general-define-key
   :states '(normal visual motion)
   :keymaps 'override
   "C-h" #'evil-window-left
   "C-j" #'evil-window-down
   "C-k" #'evil-window-up
   "C-l" #'evil-window-right
   "M-h" #'euler/resize-window-left
   "M-j" #'euler/resize-window-down
   "M-k" #'euler/resize-window-up
   "M-l" #'euler/resize-window-right))

(defvar evil-collection-magit-use-z-for-folds)
(defvar evil-collection-magit-section-use-z-for-folds)

(use-package evil-collection
  :after evil
  :ensure t
  :defer 1
  :init
  (setq evil-collection-magit-use-z-for-folds t
        evil-collection-magit-section-use-z-for-folds t)
  :config
  (evil-collection-init))

;; Quickly add parentheses around a selection by using `S-<paren>'
(use-package evil-surround
  :ensure t
  :after evil
  :defer 1
  :config
  (global-evil-surround-mode 1))

(use-package evil-textobj-tree-sitter
  :ensure t
  :defer t)

(use-package avy
  :ensure t
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
  :ensure t
  :after (embark consult)
  :defer t)

;; Embark: supercharged context-dependent menu; kinda like a
;; super-charged right-click.
(use-package embark
  :ensure t
  :commands (embark-act)
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
  ;; candidate you select.
  (with-eval-after-load 'avy
    (setf (alist-get ?. avy-dispatch-alist) 'euler/avy-action-embark)))

(provide 'ui/navigation)
