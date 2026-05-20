;;; -*- lexical-binding: t; -*-
(require 'cl-lib)
(require 'json)
(require 'subr-x)

(defvar euler/codelldb (executable-find "codelldb")
  "Path to the `codelldb' binary.
The default value assumes that `codelldb' is somewhere in Emacs' $PATH.")

(defvar euler/dape-rust-test-cargo-args
  '("test" "--no-run" "--message-format=json")
  "Cargo arguments used to build Rust test binaries for Dape.")

(defun euler/dape-rust-cargo-root ()
  "Return the nearest Cargo project root for the current buffer."
  (or (locate-dominating-file default-directory "Cargo.toml")
      (and (fboundp 'dape-cwd) (dape-cwd))
      default-directory))

(defun euler/dape-rust-cargo-bin ()
  "Return the Cargo executable used for Rust debug builds."
  (if (require 'rustic-cargo nil t)
      (rustic-cargo-bin)
    "cargo"))

(defun euler/dape-rust--path-component (relative-path index)
  "Return component INDEX from RELATIVE-PATH."
  (nth index (split-string relative-path "/" t)))

(defun euler/dape-rust--target-file-name (relative-path root)
  "Return target-like name for RELATIVE-PATH under ROOT."
  (let ((path (expand-file-name relative-path root)))
    (file-name-sans-extension (file-name-nondirectory path))))

(defun euler/dape-rust--directory-target-name (relative-path root)
  "Return Cargo target name for RELATIVE-PATH under ROOT."
  (let ((second (euler/dape-rust--path-component relative-path 1)))
    (if (and second (not (string-suffix-p ".rs" second)))
        second
      (euler/dape-rust--target-file-name relative-path root))))

(defun euler/dape-rust--path-file-stem (component)
  "Return COMPONENT without a Rust file extension."
  (when component
    (if (string-suffix-p ".rs" component)
        (file-name-sans-extension component)
      component)))

(defun euler/dape-rust--path-module-components (components)
  "Return Rust module path COMPONENTS with file syntax normalised."
  (let ((modules (mapcar #'euler/dape-rust--path-file-stem components)))
    (if (member (car (last modules)) '("main" "mod" "lib"))
        (butlast modules)
      modules)))

(defun euler/dape-rust--target-kind-p (artifact kind)
  "Return non-nil when ARTIFACT target has KIND."
  (member kind (plist-get (plist-get artifact :target) :kind)))

(defun euler/dape-rust--artifact-name (artifact)
  "Return Cargo target name for ARTIFACT."
  (plist-get (plist-get artifact :target) :name))

(defun euler/dape-rust--artifact-src-path (artifact)
  "Return Cargo target source path for ARTIFACT."
  (plist-get (plist-get artifact :target) :src_path))

(defun euler/dape-rust--artifact-kind (artifact)
  "Return primary Cargo target kind for ARTIFACT."
  (car (plist-get (plist-get artifact :target) :kind)))

(defun euler/dape-rust--file-module-components (file root artifact)
  "Return Rust module components for FILE in ROOT and ARTIFACT."
  (let* ((relative (file-relative-name file root))
         (components (split-string relative "/" t))
         (target-name (euler/dape-rust--artifact-name artifact))
         (kind (euler/dape-rust--artifact-kind artifact))
         (first (car components))
         (second (cadr components))
         (third (caddr components)))
    (cond
     ((and (equal first "src")
           (member second '("lib.rs" "main.rs")))
      nil)
     ((and (equal first "src")
           (equal second "bin"))
      (cond
       ((or (and third (string-suffix-p ".rs" third))
            (member (cadddr components) '("main.rs" "mod.rs")))
        nil)
       (t (euler/dape-rust--path-module-components (nthcdr 3 components)))))
     ((equal first "src")
      (euler/dape-rust--path-module-components (cdr components)))
     ((and (member first '("tests" "benches" "examples"))
           (member kind '("test" "bench" "example")))
      (cond
       ((equal (euler/dape-rust--target-file-name relative root) target-name)
        nil)
       ((and second (equal (euler/dape-rust--path-file-stem second) target-name))
        (euler/dape-rust--path-module-components (nthcdr 2 components)))
       (t (euler/dape-rust--path-module-components (cdr components)))))
     (t nil))))

(defun euler/dape-rust--current-function-name ()
  "Return Rust function name nearest point."
  (save-excursion
    (when (re-search-backward
           "^[[:space:]]*\\(?:pub\\(?:([^)]*)\\)?[[:space:]]+\\)?\\(?:\\(?:async\\|const\\|unsafe\\|extern\\(?:[[:space:]]+\"[^\"]+\"\\)?\\)[[:space:]]+\\)*fn[[:space:]]+\\([[:alnum:]_]+\\)"
           nil t)
      (match-string-no-properties 1))))

(defun euler/dape-rust--open-brace-contains-p (open-position position)
  "Return non-nil if brace at OPEN-POSITION still contains POSITION."
  (let ((depth 1)
        (cursor (1+ open-position)))
    (while (and (> depth 0) (< cursor position))
      (pcase (char-after cursor)
        (?{ (setq depth (1+ depth)))
        (?} (setq depth (1- depth))))
      (setq cursor (1+ cursor)))
    (> depth 0)))

(defun euler/dape-rust--inline-module-components (position)
  "Return inline Rust module components containing POSITION."
  (let (modules)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              "^[[:space:]]*\\(?:pub\\(?:([^)]*)\\)?[[:space:]]+\\)?mod[[:space:]]+\\([[:alnum:]_]+\\)[[:space:]]*{"
              position t)
        (when (euler/dape-rust--open-brace-contains-p (1- (point)) position)
          (push (match-string-no-properties 1) modules))))
    (nreverse modules)))

(defun euler/dape-rust-current-test-name (root artifact)
  "Return the Rust test path near point for ROOT and ARTIFACT."
  (when-let* ((file (buffer-file-name))
              (function-name (euler/dape-rust--current-function-name)))
    (mapconcat #'identity
               (append (euler/dape-rust--file-module-components file root artifact)
                       (euler/dape-rust--inline-module-components (point))
                       (list function-name))
               "::")))

(defun euler/dape-rust--artifact-score (artifact file root target-name target-kind)
  "Return how well ARTIFACT matches FILE in ROOT."
  (let* ((name (euler/dape-rust--artifact-name artifact))
         (src-path (euler/dape-rust--artifact-src-path artifact))
         (relative (file-relative-name file root))
         (first (euler/dape-rust--path-component relative 0))
         (second (euler/dape-rust--path-component relative 1))
         (third (euler/dape-rust--path-component relative 2)))
    (+ (cond
        ((and target-name target-kind
              (equal name target-name)
              (euler/dape-rust--target-kind-p artifact target-kind))
         200)
        ((and target-name (equal name target-name))
         150)
        ((and target-kind (euler/dape-rust--target-kind-p artifact target-kind))
         125)
        ((and src-path (file-equal-p file src-path))
         100)
        ((and (equal first "tests")
              (euler/dape-rust--target-kind-p artifact "test")
              (equal name (euler/dape-rust--directory-target-name relative root)))
         90)
        ((and (equal first "benches")
              (euler/dape-rust--target-kind-p artifact "bench")
              (equal name (euler/dape-rust--directory-target-name relative root)))
         90)
        ((and (equal first "examples")
              (euler/dape-rust--target-kind-p artifact "example")
              (equal name (euler/dape-rust--directory-target-name relative root)))
         90)
        ((and (equal first "src")
              (equal second "bin")
              (euler/dape-rust--target-kind-p artifact "bin")
              (equal name (if (and third (not (string-suffix-p ".rs" third)))
                              third
                            (euler/dape-rust--target-file-name relative root))))
         90)
        ((and (equal first "src")
              (euler/dape-rust--target-kind-p artifact "lib"))
         70)
        ((and (equal first "src")
              (euler/dape-rust--target-kind-p artifact "bin"))
         60)
        ((euler/dape-rust--target-kind-p artifact "test")
         10)
        (t 0))
       (if (plist-get artifact :executable) 1 0))))

(defun euler/dape-rust--artifact-label (artifact)
  "Return human-readable label for ARTIFACT."
  (format "%s %S %s"
          (euler/dape-rust--artifact-name artifact)
          (plist-get (plist-get artifact :target) :kind)
          (plist-get artifact :executable)))

(defun euler/dape-rust--select-artifact (artifacts root target-name target-kind)
  "Select best test ARTIFACT from ARTIFACTS for current buffer."
  (unless artifacts
    (user-error "Cargo produced no test executable artifacts"))
  (if (null (cdr artifacts))
      (car artifacts)
    (let* ((file (buffer-file-name))
           (scored (sort (mapcar (lambda (artifact)
                                   (cons (euler/dape-rust--artifact-score
                                          artifact file root target-name target-kind)
                                         artifact))
                                 artifacts)
                         (lambda (left right) (> (car left) (car right)))))
           (best (car scored))
           (next (cadr scored)))
      (if (and best (or (null next) (> (car best) (car next))))
          (cdr best)
        (user-error "Ambiguous Rust test artifact; pass target-name/target-kind. Candidates: %s"
                    (mapconcat #'euler/dape-rust--artifact-label artifacts "; "))))))

(defun euler/dape-rust--read-json-line ()
  "Read JSON object from current line, or nil."
  (let ((line (buffer-substring-no-properties
               (line-beginning-position) (line-end-position))))
    (unless (string-empty-p line)
      (with-temp-buffer
        (insert line)
        (goto-char (point-min))
        (ignore-errors
          (json-parse-buffer :object-type 'plist
                             :array-type 'list
                             :null-object nil
                             :false-object nil))))))

(defun euler/dape-rust--cargo-args (config)
  "Return Cargo args from CONFIG as a concrete list."
  (let ((args (or (plist-get config 'cargo-args)
                  euler/dape-rust-test-cargo-args)))
    (cond
     ((symbolp args) (symbol-value args))
     ((listp args) args)
     ((vectorp args) (append args nil))
     (t (user-error "Rust Dape cargo-args must be a list or vector")))))

(defun euler/dape-rust--command (config)
  "Return debug adapter command from CONFIG as a concrete string."
  (let* ((command (plist-get config 'command))
         (resolved (cond
                    ((eq command 'euler/codelldb)
                     (or euler/codelldb (executable-find "codelldb") "codelldb"))
                    ((and (symbolp command) (boundp command))
                     (symbol-value command))
                    ((functionp command)
                     (funcall command))
                    (t command))))
    (unless (stringp resolved)
      (user-error "Rust Dape command must resolve to a string"))
    resolved))

(defun euler/dape-rust--cargo-test-artifacts (root cargo-args)
  "Build Rust tests in ROOT with CARGO-ARGS and return executable artifacts."
  (let* ((source-buffer (current-buffer))
         (output-buffer (get-buffer-create "*euler-rust-test-build*"))
         (cargo-bin (euler/dape-rust-cargo-bin))
         (saved-env process-environment)
         (saved-exec-path exec-path)
         status artifacts)
    (with-current-buffer output-buffer
      (let ((inhibit-read-only t)
            (default-directory root)
            (process-environment saved-env)
            (exec-path saved-exec-path))
        (erase-buffer)
        (setq status (apply #'call-process cargo-bin nil output-buffer t cargo-args))
        (unless (zerop status)
          (display-buffer output-buffer)
          (user-error "Cargo test build failed with status %s" status))
        (goto-char (point-min))
        (while (not (eobp))
          (when-let* ((object (euler/dape-rust--read-json-line))
                      ((equal (plist-get object :reason) "compiler-artifact"))
                      ((plist-get object :executable)))
            (push object artifacts))
          (forward-line 1))))
    (with-current-buffer source-buffer
      (nreverse artifacts))))

(defun euler/dape-rust--listed-test-names (program root)
  "Return test names reported by PROGRAM's Rust test harness in ROOT."
  (let ((output-buffer (get-buffer-create "*euler-rust-test-list*"))
        (saved-env process-environment)
        (saved-exec-path exec-path)
        status tests)
    (with-current-buffer output-buffer
      (let ((inhibit-read-only t)
            (default-directory root)
            (process-environment saved-env)
            (exec-path saved-exec-path))
        (erase-buffer)
        (setq status (call-process program nil output-buffer t "--list"))
        (unless (zerop status)
          (display-buffer output-buffer)
          (user-error "Rust test listing failed with status %s" status))
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position))))
            (when (string-match "\\`\\(.+\\): \\(test\\|benchmark\\)\\'" line)
              (push (match-string 1 line) tests)))
          (forward-line 1))))
    (nreverse tests)))

(defun euler/dape-rust--common-suffix-length (left right)
  "Return count of common trailing path components in LEFT and RIGHT."
  (let ((left-parts (reverse (split-string left "::" t)))
        (right-parts (reverse (split-string right "::" t)))
        (count 0))
    (while (and left-parts right-parts
                (equal (car left-parts) (car right-parts)))
      (setq count (1+ count)
            left-parts (cdr left-parts)
            right-parts (cdr right-parts)))
    count))

(defun euler/dape-rust--test-match-score (candidate listed)
  "Return match score between CANDIDATE test path and LISTED test path."
  (cond
   ((equal candidate listed) 1000)
   ((equal (car (last (split-string candidate "::" t)))
           (car (last (split-string listed "::" t))))
    (euler/dape-rust--common-suffix-length candidate listed))
   (t 0)))

(defun euler/dape-rust--resolve-listed-test-name (candidate tests)
  "Return actual test name from TESTS best matching CANDIDATE."
  (unless tests
    (user-error "Rust test harness listed no tests"))
  (unless (and candidate (not (string-empty-p candidate)))
    (setq candidate (completing-read "Rust test name: " tests nil t)))
  (let* ((scored (sort (mapcar (lambda (test)
                                 (cons (euler/dape-rust--test-match-score
                                        candidate test)
                                       test))
                               tests)
                       (lambda (left right) (> (car left) (car right)))))
         (best (car scored))
         (next (cadr scored)))
    (cond
     ((zerop (car best))
      (user-error "No listed Rust test matches %s" candidate))
     ((and next (= (car best) (car next)))
      (user-error "Ambiguous Rust test match for %s: %s"
                  candidate
                  (mapconcat #'cdr
                             (cl-remove-if-not
                              (lambda (item) (= (car item) (car best))) scored)
                             ", ")))
     (t (cdr best)))))

(defun euler/dape-rust--test-name (program root artifact)
  "Return exact Rust test harness name for PROGRAM in ROOT."
  (euler/dape-rust--resolve-listed-test-name
   (euler/dape-rust-current-test-name root artifact)
   (euler/dape-rust--listed-test-names program root)))

(defun euler/dape-rust-test-config (config)
  "Build current Rust test binary and add it to Dape CONFIG."
  (unless (buffer-file-name)
    (user-error "No Rust buffer file"))
  (let* ((root (file-name-as-directory (expand-file-name (euler/dape-rust-cargo-root))))
         (cargo-args (euler/dape-rust--cargo-args config))
         (target-name (plist-get config 'target-name))
         (target-kind (plist-get config 'target-kind))
         (artifact (euler/dape-rust--select-artifact
                    (euler/dape-rust--cargo-test-artifacts root cargo-args)
                    root target-name target-kind))
         (program (plist-get artifact :executable))
         (test-name (euler/dape-rust--test-name program root artifact)))
    (setq config (plist-put config 'command (euler/dape-rust--command config)))
    (setq config (plist-put config 'command-cwd root))
    (setq config (plist-put config :cwd root))
    (unless (plist-member config :breakpointMode)
      (setq config (plist-put config :breakpointMode "file")))
    (unless (plist-member config :program)
      (setq config (plist-put config :program program)))
    (unless (plist-member config :args)
      (when (string-empty-p test-name)
        (user-error "No Rust test name found"))
      (setq config (plist-put config :args
                              (vector test-name "--exact" "--nocapture"))))
    config))

(defun euler/dape-rust-test ()
  "Debug the Rust test nearest point with Dape and CodeLLDB."
  (interactive)
  (require 'dape)
  (dape (copy-tree (alist-get 'codelldb-rust-test dape-configs))))

(use-package dape
  :ensure t
  :commands (dape
             dape-breakpoint-toggle
             dape-breakpoint-save
             dape-breakpoint-load)
  :preface
  ;; By default dape shares the same keybinding prefix as `gud'
  ;; If you do not want to use any prefix, set it to nil.
  ;; (setq dape-key-prefix "\C-x\C-a")

  ;; Info buffers to the right
  ;; (dape-buffer-window-arrangement 'right)
  ;; Info buffers like gud (gdb-mi)
  ;; (dape-buffer-window-arrangement 'gud)
  ;; (dape-info-hide-mode-line nil)

  ;; Projectile users
  ;; (dape-cwd-function #'projectile-project-root)

  :init
  (setq dape-default-breakpoints-file
        (locate-user-emacs-file "dape-breakpoints"))

  :config
  ;; Pulse source line (performance hit)
  ;; (add-hook 'dape-display-source-hook #'pulse-momentary-highlight-one-line)

  ;; Save buffers on startup, useful for interpreted languages
  ;; (add-hook 'dape-start-hook (lambda () (save-some-buffers t t)))

  ;; Kill compile buffer on build success
  ;; (add-hook 'dape-compile-hook #'kill-buffer)
  ;; Save breakpoints only after Dape has been loaded.
  (add-hook 'kill-emacs-hook #'dape-breakpoint-save)
  (dape-breakpoint-load)
  (dape-breakpoint-global-mode +1)
  ;; Debug Rust with `codelldb'
  (add-to-list 'dape-configs
	       `(codelldb-rust
                  modes (rust-mode rust-ts-mode rustic-mode)
		 command-cwd dape-command-cwd
                  command euler/codelldb
                  :type "lldb"
                  :request "launch"
                  :breakpointMode "file"
                  command-args ("--port"
			       :autoport
			       "--settings" "{\"sourceLanguages\":[\"rust\"]}")
                 ensure dape-ensure-command port :autoport fn dape-config-autoport
                 :cwd dape-cwd-fn
                 :program (lambda ()
                            (file-name-concat "target" "debug"
                                              (thread-first (dape-cwd)
                                                            (directory-file-name)
                                                            (file-name-split)
                                                            (last)
                                                            (car))))
                  :args []))
  ;; Debug the Rust test nearest point.  This builds with Cargo JSON output so
  ;; hashed test binaries under target/debug/deps do not need manual selection.
  (add-to-list 'dape-configs
	       `(codelldb-rust-test
                  modes (rust-mode rust-ts-mode rustic-mode)
		 command-cwd euler/dape-rust-cargo-root
                  command euler/codelldb
                  command-args ("--port"
			       :autoport
			       "--settings" "{\"sourceLanguages\":[\"rust\"]}")
                  ensure dape-ensure-command
                  port :autoport
                  fn euler/dape-rust-test-config
                  :type "lldb"
                  :request "launch"
                  :sourceLanguages ["rust"]
                  :breakpointMode "file"
                  cargo-args euler/dape-rust-test-cargo-args))
  ;; Debug C with `codelldb'
  (add-to-list 'dape-configs
	       '(my-codelldb-cc
		 modes (c-mode c-ts-mode c++-mode c++-ts-mode)
		 ensure dape-ensure-command
		 command-cwd dape-command-cwd
		 command euler/codelldb
		 command-args ("--port" :autoport)
		 port :autoport
		 :type "lldb"
		 :request "launch"
		 :name "Codelldb: Launch current file"
		 :cwd "."
		 :program (lambda ()
			    (let* ((source-file (buffer-file-name))
				   (dir (file-name-directory source-file))
				   (name (file-name-sans-extension
					  (file-name-nondirectory source-file))))
			      (concat dir name)))
                 :args []
		 :stopOnEntry nil)))

;; For a more ergonomic Emacs and `dape' experience
(use-package repeat
  :ensure nil
  :defer 1
  :config
  (repeat-mode 1))

(provide 'tools/debug)
