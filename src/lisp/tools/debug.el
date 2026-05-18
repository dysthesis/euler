;;; -*- lexical-binding: t; -*-
(defvar euler/codelldb (executable-find "codelldb")
  "Path to the `codelldb' binary.
The default value assumes that `codelldb' is somewhere in Emacs' $PATH.")

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
                 modes (rust-mode rust-ts-mode)
		 command-cwd dape-command-cwd
                 command euler/codelldb
                 :type "lldb"
                 :request "launch"
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
