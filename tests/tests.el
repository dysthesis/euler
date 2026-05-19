;;; tests.el --- Tests for Euler -*- lexical-binding: t; -*-

(require 'test-helper)

(euler-test-load-config)

(ert-deftest euler-test-wrapper-runtime-tools-present ()
  "Wrapped runtime should contain every external tool configured by Lisp."
  (let* ((programs '("git" "rg" "fd" "rsync" "emacs-lsp-booster" "clangd"
                     "cmake" "cmake-language-server" "codelldb" "nil"
                     "rust-analyzer" "zls" "alejandra" "prettier" "shfmt"))
         (expr (concat "(let ((programs '" (prin1-to-string programs) "))"
                       "  (dolist (program programs)"
                       "    (princ program)"
                       "    (princ \"\\t\")"
                       "    (princ (or (executable-find program) \"MISSING\"))"
                       "    (princ \"\\n\")))"))
         (result (euler-test-run-wrapped-emacs (list expr)))
         (status (car result))
         (output (cadr result))
         missing)
    (should (= status 0))
    (dolist (line (split-string output "\n" t))
      (pcase (split-string line "\t")
        (`(,program "MISSING")
         (push program missing))))
    (should (null (nreverse missing)))))

(ert-deftest euler-test-mode-dispatch-never-fundamental ()
  "Configured language files should never fall through to `fundamental-mode'."
  (dolist (case '((".zig" . (zig-ts-mode zig-mode))
                  (".rs" . (rust-ts-mode rust-mode rustic-mode))
                  (".nix" . (nix-ts-mode nix-mode))
                  (".c" . (c-ts-mode c-mode))
                  (".cpp" . (c++-ts-mode c++-mode))))
    (pcase-let ((`(,suffix . ,expected-modes) case))
      (euler-test-with-temp-file suffix ""
        (should (not (eq major-mode 'fundamental-mode)))
        (should (memq major-mode expected-modes))))))

(ert-deftest euler-test-elsa-input-paths-exist ()
  "Every Elisp path hard-coded into the Elsa check should exist."
  (let ((nix-file (expand-file-name "nix/packages/default.nix" euler-test-root))
        missing)
    (with-temp-buffer
      (insert-file-contents nix-file)
      (goto-char (point-min))
      (while (re-search-forward "src/[[:alnum:]_./-]+\\.el" nil t)
        (let ((path (match-string 0)))
          (unless (file-exists-p (expand-file-name path euler-test-root))
            (push path missing)))))
    (should (null (delete-dups (nreverse missing))))))

(ert-deftest euler-test-custom-file-is-loaded ()
  "A pre-existing `custom-file' should affect the next startup."
  (let* ((root (make-temp-file "euler-test-custom-" t))
         (state (expand-file-name "state" root))
         (custom (expand-file-name "euler/emacs/custom.el" state)))
    (make-directory (file-name-directory custom) t)
    (write-region "(setq euler-test-custom-loaded t)\n" nil custom nil 'silent)
    (let* ((result (euler-test-run-source-emacs
                    '("(princ (if (bound-and-true-p euler-test-custom-loaded) \"loaded\" \"missing\"))")
                    (list (concat "XDG_STATE_HOME=" state))))
           (status (car result))
           (output (string-trim (cadr result))))
      (should (= status 0))
      (should (string= output "loaded")))))

(ert-deftest euler-test-recentf-provider-live ()
  "The recent-file key binding should have a live recentf provider."
  (should (fboundp 'consult-recent-file))
  (should (bound-and-true-p recentf-mode))
  (should (and (boundp 'recentf-save-file)
               (stringp recentf-save-file)
               (file-name-absolute-p recentf-save-file))))

(ert-deftest euler-test-eglot-formatter-roundtrip ()
  "Toggling Eglot formatting should restore the exact previous formatter value."
  (dolist (initial '(nil alejandra (alejandra) (eglot alejandra) (prettier eglot prettier-json)))
    (with-temp-buffer
      (setq-local euler/format-with (copy-tree initial))
      (euler/format-with-eglot-mode 1)
      (euler/format-with-eglot-mode -1)
      (should (equal euler/format-with initial)))))

(ert-deftest euler-test-prettier-cache-tracks-filesystem ()
  "Prettier config cache should not lie after project files change."
  (let ((dir (make-temp-file "euler-test-prettier-" t))
        (euler/format-prettier-config-cache-ttl 3600))
    (unwind-protect
        (let ((default-directory dir))
          (euler/format-clear-prettier-config-cache)
          (should-not (euler/format--prettier-configured-p))
          (write-region "{}\n" nil (expand-file-name ".prettierrc" dir) nil 'silent)
          (should (euler/format--prettier-configured-p)))
      (delete-directory dir t))))

(ert-deftest euler-test-fold-init-flag-only-after-success ()
  "Auto-fold one-shot state should not be consumed by a failed fold attempt."
  (with-temp-buffer
    (setq-local treesit-fold-mode t)
    (setq-local euler/treesit-fold-bodies-initialized nil)
    (cl-letf (((symbol-function 'euler/treesit-fold--body-candidates)
               (lambda (&optional _whole-buffer)
                 (error "test query failure"))))
      (ignore-errors (euler/treesit-fold-close-function-bodies-once))
      (should-not euler/treesit-fold-bodies-initialized))))

(ert-deftest euler-test-eglot-starts-after-local-env ()
  "Deferred Eglot startup should observe the final buffer-local environment."
  (let ((old-path (getenv "PATH"))
        captured-path
        timer-fn
        timer-args)
    (unwind-protect
        (cl-letf (((symbol-function 'project-current) (lambda (&optional _dir) t))
                  ((symbol-function 'run-with-idle-timer)
                   (lambda (_secs _repeat fn &rest args)
                     (setq timer-fn fn
                           timer-args args)
                     'euler-test-timer))
                  ((symbol-function 'eglot-ensure)
                   (lambda ()
                     (setq captured-path (getenv "PATH")))))
          (with-temp-buffer
            (setenv "PATH" "stale-path")
            (euler/eglot-ensure-deferred)
            (apply timer-fn timer-args)
            (setenv "PATH" "fresh-path")
            (should (equal captured-path "fresh-path"))))
      (setenv "PATH" old-path))))

(defun euler-test--wide-string (trial)
  "Return a deterministic string containing mixed-width characters for TRIAL."
  (let ((alphabet (append (number-sequence ?a ?z)
                          (list #x03bb #x4e2d #x754c)))
        (len (1+ (mod (* 7 (1+ trial)) 18)))
        chars)
    (dotimes (index len)
      (push (nth (mod (+ trial (* 5 index)) (length alphabet)) alphabet)
            chars))
    (apply #'string (nreverse chars))))

(ert-deftest euler-test-mode-line-truncation-width-bound ()
  "Left truncation should bound display width, not merely character count."
  (euler-test-check-property
   "mode-line truncate-left width bound"
   200
   (lambda (trial)
     (list :text (euler-test--wide-string trial)
           :max-width (+ 4 (mod (* 3 trial) 12))))
   (lambda (case)
     (let* ((text (plist-get case :text))
            (max-width (plist-get case :max-width))
            (truncated (euler/mode-line--truncate-left text max-width)))
       (<= (string-width truncated) max-width)))))

(ert-deftest euler-test-org-flyspell-nil-program-safe ()
  "Org flyspell gate should tolerate `ispell-program-name' being nil."
  (with-temp-buffer
    (let ((ispell-program-name nil))
      (should-not (euler-test-signals-p #'euler/org-flyspell-mode-maybe)))))

(ert-deftest euler-test-private-api-contracts-present ()
  "Private APIs used by the config should still exist after package load."
  (dolist (feature '(eglot treesit-fold dirvish magit dired))
    (should (require feature nil t)))
  (dolist (symbol '(eglot--managed-buffers
                    eglot--TextDocumentPositionParams
                    eglot--request
                    eglot--apply-text-edits
                    treesit-fold--create-overlay
                    treesit-fold--get-fold-range
                    dirvish--find-entry
                    dirvish-dired-noselect-a
                    dired--find-file
                    magit-mode-get-buffers))
    (should (fboundp symbol)))
  (dolist (symbol '(eglot--managed-mode magit--default-directory))
    (should (boundp symbol))))

;;; tests.el ends here
