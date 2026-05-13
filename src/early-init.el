;;; -*- lexical-binding: t; -*-
;;; Mainly from emacs-bedrock
;; Startup speed, annoyance suppression
(defvar euler--initial-gc-threshold gc-cons-threshold
  "GC threshold before startup tuning.")
(setq gc-cons-threshold 10000000)
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold euler--initial-gc-threshold)))
(setq byte-compile-warnings '(not obsolete))
(setq warning-suppress-log-types '((comp) (bytecomp)))
(setq native-comp-async-report-warnings-errors 'silent)

;; Packages are baked in by Nix (via emacsWithPackagesFromUsePackage).
;; Let `package-initialize' still run at startup so the bundled autoloads are
;; registered, but block any runtime network use so package.el cannot try to
;; install or refresh archives.
(setq package-archives nil)

;; Silence stupid startup message
(setq inhibit-startup-echo-area-message (user-login-name))

;; Since the config lives in Nix, tell Emacs to put state in XDG_STATE_HOME, where
;; it is able to write to it.
(let* ((store-dir (file-name-directory (or load-file-name buffer-file-name)))
       (state-root
        (expand-file-name "euler"
                          (or (getenv "XDG_STATE_HOME")
                              (expand-file-name "~/.local/state/"))))
       (native-lisp-dir (expand-file-name "share/emacs/native-lisp" store-dir)))
  (add-to-list 'custom-theme-load-path
               (expand-file-name "themes" store-dir))
  ;; Keep config in the store; direct all writable state elsewhere.
  (setq user-init-file        (expand-file-name "init.el" store-dir)
        early-init-file       (expand-file-name "early-init.el" store-dir)
        user-emacs-directory  (file-name-as-directory
                               (expand-file-name "emacs" state-root))
        package-user-dir      (expand-file-name "elpa" user-emacs-directory)
        package-quickstart    nil
        package-quickstart-file (expand-file-name "package-quickstart.el" user-emacs-directory))
  (when (boundp 'native-comp-eln-load-path)
    (let ((state-eln-cache (expand-file-name "eln-cache/" user-emacs-directory))
          (kept-native-paths nil))
      (dolist (dir native-comp-eln-load-path)
        (when (and (stringp dir)
                   (not (string-prefix-p store-dir (expand-file-name dir)))
                   (not (string= native-lisp-dir (directory-file-name dir))))
          (push dir kept-native-paths)))
      (setq native-comp-eln-load-path
            (cons native-lisp-dir
                  (cons state-eln-cache (nreverse kept-native-paths)))))))

;; Default frame configuration: full screen, good-looking title bar on macOS
(setq frame-resize-pixelwise t)
(tool-bar-mode -1)                      ; All these tools are in the menu-bar anyway
(setq default-frame-alist '((fullscreen . maximized)

                            ;; You can turn off scroll bars by uncommenting these lines:
                            ;; (vertical-scroll-bars . nil)
                            ;; (horizontal-scroll-bars . nil)

                            ;; Setting the face in here prevents flashes of
                            ;; color as the theme gets activated
                            (background-color . "#000000")
                            (foreground-color . "#ffffff")
                            (ns-appearance . dark)
                            (ns-transparent-titlebar . t)))
