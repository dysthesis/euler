;;; -*- lexical-binding: t; -*-
(require 'core/lib)
(require 'ui/keys)

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
(defvar treesit-fold-mode-map)
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

(defcustom euler/treesit-fold-context-lines 200
  "Lines above and below point to search for foldable bodies.
Larger values are more thorough but slower in big files."
  :type 'integer
  :group 'euler/lsp)

(defun euler/treesit-fold-mode-maybe ()
  "Enable Tree-sitter folding when the current buffer is not large."
  (unless (euler/large-buffer-p)
    (treesit-fold-mode 1)))

;; (euler/treesit-fold--body-candidates :: (function () mixed))
(defun euler/treesit-fold--body-candidates (&optional whole-buffer)
  "Return body fold candidates near point in the current buffer.
When WHOLE-BUFFER is non-nil, search the entire buffer.
Each candidate is (TARGET-RANGE . FOLD-RANGE)."
  (let* ((rule (euler/treesit-fold--body-rule))
         (query-text (and rule (plist-get rule :query))))
    (when (and query-text (treesit-fold-ready-p))
      (let* ((root (treesit-buffer-root-node))
             (language (and root (treesit-node-language root)))
             (query (and language
                         (euler/treesit-fold--body-query language query-text)))
             ;; Restrict capture to a window around point instead of
             ;; the full buffer, so large files don't pay full-tree cost.
              (beg (if whole-buffer
                       (point-min)
                     (save-excursion
                       (forward-line (- euler/treesit-fold-context-lines))
                       (point))))
              (end (if whole-buffer
                       (point-max)
                     (save-excursion
                       (forward-line euler/treesit-fold-context-lines)
                       (point)))))
        (when query
          (condition-case nil
              (let (candidates)
                (dolist (capture
                         (treesit-query-capture root query beg end) 
                         (nreverse candidates))
                  (let* ((capture-name (car capture))
                         (node (cdr capture))
                         (target (euler/treesit-fold--target-node-for-capture
                                  capture-name node))
                         (target-range
                          (and target
                               (cons (treesit-node-start target)
                                     (treesit-node-end target))))
                         (fold-range
                          (euler/treesit-fold--fold-range-for-capture
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
(defun euler/treesit-fold-close-function-bodies (&optional whole-buffer)
  "Fold nearby function and method bodies.
With prefix argument WHOLE-BUFFER, fold the entire buffer."
  (interactive "P")
  (when (bound-and-true-p treesit-fold-mode)
    (let (folded)
      (dolist (candidate (euler/treesit-fold--body-candidates whole-buffer))
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

;; (euler/treesit-fold--candidate-on-line-p :: (function (mixed int) bool))
(defun euler/treesit-fold--candidate-on-line-p (candidate line)
  "Return non-nil when CANDIDATE can be toggled from LINE."
  (let ((target (car candidate))
        (range (cdr candidate)))
    (or (= line (line-number-at-pos (car target) t))
        (= line (line-number-at-pos (car range) t)))))

;; (euler/treesit-fold--candidate-on-current-line :: (function () mixed))
(defun euler/treesit-fold--candidate-on-current-line ()
  "Return fold candidate whose header or fold start is on the current line."
  (let ((line (line-number-at-pos (point) t)))
    (euler/find-if
     (lambda (candidate)
       (euler/treesit-fold--candidate-on-line-p candidate line))
     (euler/treesit-fold--body-candidates))))

;; (euler/treesit-fold-toggle-dwim :: (function () mixed))
(defun euler/treesit-fold-toggle-dwim ()
  "Toggle a fold on the current line, otherwise run normal TAB behavior."
  (interactive)
  (let ((candidate (and (bound-and-true-p treesit-fold-mode)
                        (euler/treesit-fold--candidate-on-current-line))))
    (if candidate
        (let ((range (cdr candidate)))
          (if (euler/treesit-fold--delete-overlays-at-range range)
              (run-hooks 'treesit-fold-on-fold-hook)
            (when (treesit-fold--create-overlay range)
	      (run-hooks 'treesit-fold-on-fold-hook))))
      (call-interactively #'indent-for-tab-command))))

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
  :commands (treesit-fold-mode treesit-fold-toggle)
  :hook (prog-mode . euler/treesit-fold-mode-maybe)
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
  (define-key treesit-fold-mode-map (kbd "<tab>")
              #'euler/treesit-fold-toggle-dwim)
  (dysthesis/start/leader-keys
    "c f" '(treesit-fold-toggle :wk "[C]ode [F]old")
    "c F" '(euler/treesit-fold-close-function-bodies :wk "[C]ode [F]old bodies")))

(provide 'dev/fold)
