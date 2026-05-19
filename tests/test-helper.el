;;; test-helper.el --- Helpers for Euler tests -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'subr-x)

(defconst euler-test-root
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Repository root for tests.")

(defconst euler-test-src
  (expand-file-name "src" euler-test-root)
  "Euler source directory.")

(defconst euler-test-lisp
  (expand-file-name "lisp" euler-test-src)
  "Euler Lisp directory.")

(defconst euler-test-themes
  (expand-file-name "themes" euler-test-src)
  "Euler theme directory.")

(defconst euler-test-emacs
  (or (getenv "EULER_TEST_EMACS")
      (expand-file-name invocation-name invocation-directory))
  "Emacs executable used for source-load subprocess tests.")

(defconst euler-test-wrapped-emacs
  (or (getenv "EULER_TEST_WRAPPED_EMACS")
      (let ((candidate (expand-file-name "result/bin/emacs" euler-test-root)))
        (and (file-executable-p candidate) candidate))
      euler-test-emacs)
  "Wrapped Euler Emacs executable used for runtime closure tests.")

(defvar euler-test--loaded nil
  "Non-nil after the Euler config has been loaded in this process.")

(defvar euler-test--sandbox-root
  (make-temp-file "euler-test-state-" t)
  "Writable state root for tests that load the Euler config.")

(defun euler-test--mkdir (path)
  "Create PATH and return it."
  (make-directory path t)
  path)

(defun euler-test-load-config ()
  "Load Euler config once in the current Emacs process."
  (unless euler-test--loaded
    (setq default-directory euler-test-root)
    (setenv "HOME" (euler-test--mkdir (expand-file-name "home" euler-test--sandbox-root)))
    (setenv "XDG_STATE_HOME" (euler-test--mkdir (expand-file-name "state" euler-test--sandbox-root)))
    (setenv "XDG_CACHE_HOME" (euler-test--mkdir (expand-file-name "cache" euler-test--sandbox-root)))
    (setenv "XDG_CONFIG_HOME" (euler-test--mkdir (expand-file-name "config" euler-test--sandbox-root)))
    (setenv "EMACSNATIVELOADPATH" (euler-test--mkdir (expand-file-name "eln" euler-test--sandbox-root)))
    (add-to-list 'load-path euler-test-src)
    (add-to-list 'load-path euler-test-lisp)
    (add-to-list 'custom-theme-load-path euler-test-themes)
    (require 'package)
    (package-activate-all)
    (load (expand-file-name "early-init.el" euler-test-src) nil t)
    (load (expand-file-name "init.el" euler-test-src) nil t)
    (setq euler-test--loaded t)))

(defun euler-test--process-environment (&optional env)
  "Return a minimal process environment extended by ENV."
  (let* ((root (make-temp-file "euler-test-subprocess-" t))
         (home (euler-test--mkdir (expand-file-name "home" root)))
         (state (euler-test--mkdir (expand-file-name "state" root)))
         (cache (euler-test--mkdir (expand-file-name "cache" root)))
         (config (euler-test--mkdir (expand-file-name "config" root)))
         (eln (euler-test--mkdir (expand-file-name "eln" root))))
    (append env
            (list (concat "HOME=" home)
                  (concat "XDG_STATE_HOME=" state)
                  (concat "XDG_CACHE_HOME=" cache)
                  (concat "XDG_CONFIG_HOME=" config)
                  (concat "EMACSNATIVELOADPATH=" eln)
                  "PATH=/no-such-path"
                  "TERM=dumb"))))

(defun euler-test-call-process (program args &optional env)
  "Call PROGRAM with ARGS and ENV. Return (STATUS OUTPUT)."
  (with-temp-buffer
    (let ((default-directory euler-test-root)
          (process-environment (euler-test--process-environment env)))
      (list (apply #'call-process program nil t nil args)
            (buffer-string)))))

(defun euler-test-run-source-emacs (evals &optional env)
  "Run a source-loading Emacs subprocess with EVALS and ENV."
  (let ((args (append (list "--batch" "-Q"
                           "-f" "package-activate-all"
                           "-L" euler-test-src
                           "-L" euler-test-lisp
                           "-L" euler-test-themes
                           "-l" (expand-file-name "early-init.el" euler-test-src)
                           "-l" (expand-file-name "init.el" euler-test-src))
                     (cl-mapcan (lambda (expr) (list "--eval" expr)) evals))))
    (euler-test-call-process euler-test-emacs args env)))

(defun euler-test-run-wrapped-emacs (evals &optional env)
  "Run wrapped Euler Emacs with EVALS and ENV."
  (let ((args (append (list "--batch" "-Q")
                     (cl-mapcan (lambda (expr) (list "--eval" expr)) evals))))
    (euler-test-call-process euler-test-wrapped-emacs args env)))

(defmacro euler-test-with-temp-file (suffix contents &rest body)
  "Create a temporary file with SUFFIX and CONTENTS, then run BODY."
  (declare (indent 2))
  `(let ((file (make-temp-file "euler-test-" nil ,suffix ,contents)))
     (unwind-protect
         (let ((buffer (find-file-noselect file)))
           (unwind-protect
               (with-current-buffer buffer
                 ,@body)
             (when (buffer-live-p buffer)
               (kill-buffer buffer))))
       (when (file-exists-p file)
         (delete-file file)))))

(defun euler-test-signals-p (fn)
  "Return non-nil when calling FN signals an error."
  (condition-case _err
      (progn (funcall fn) nil)
    (error t)))

(defun euler-test-check-property (name trials generator predicate)
  "Run property NAME for TRIALS using GENERATOR and PREDICATE."
  (cl-loop for trial below trials
           for value = (funcall generator trial)
           for ok = (condition-case err
                        (funcall predicate value)
                      (error
                       (ert-fail (format "Property %s signalled on trial %d with value %S: %S"
                                         name trial value err))))
           unless ok
           do (ert-fail (format "Property %s failed on trial %d with value %S"
                                name trial value))))

(provide 'test-helper)

;;; test-helper.el ends here
