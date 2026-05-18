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

(defvar euler/package-quickstart-stamp nil
  "Fingerprint for the package set used to build the quickstart file.")

(defvar euler/package-quickstart-stamp-file nil
  "File recording `euler/package-quickstart-stamp'.")

(defun euler/package-quickstart--stamp-value ()
  "Return a fingerprint for startup package and native-load paths."
  (secure-hash
   'sha1
   (mapconcat
    #'identity
    (sort (copy-sequence
           (append load-path
                   (split-string (or (getenv "EMACSNATIVELOADPATH") "")
                                 path-separator t)))
          #'string<)
    "\n")))

(defun euler/package-quickstart-valid-p ()
  "Return non-nil when the quickstart file matches the current package set."
  (and package-quickstart-file
       euler/package-quickstart-stamp-file
       (file-readable-p package-quickstart-file)
       (file-readable-p euler/package-quickstart-stamp-file)
       (string= euler/package-quickstart-stamp
                (with-temp-buffer
                  (insert-file-contents euler/package-quickstart-stamp-file)
                  (string-trim (buffer-string))))))

(defun euler/package-quickstart-refresh-maybe ()
  "Refresh package quickstart after startup if the package set changed."
  (when (and (require 'package nil t)
             (fboundp 'package-quickstart-refresh)
             (not (euler/package-quickstart-valid-p)))
    (make-directory (file-name-directory package-quickstart-file) t)
    (package-quickstart-refresh)
    (with-temp-file euler/package-quickstart-stamp-file
      (insert euler/package-quickstart-stamp "\n"))))

;; Silence stupid startup message
(setq inhibit-startup-echo-area-message (user-login-name))

;; Since the config lives in Nix, tell Emacs to put state in XDG_STATE_HOME, where
;; it is able to write to it.
(let* ((store-dir (file-name-directory (or load-file-name buffer-file-name)))
       (lisp-dir (expand-file-name "lisp" store-dir))
       (state-root
        (expand-file-name "euler"
                          (or (getenv "XDG_STATE_HOME")
                              (expand-file-name "~/.local/state/"))))
       (native-lisp-dir (expand-file-name "share/emacs/native-lisp" store-dir))
       (quickstart-file (expand-file-name "package-quickstart.el"
                                          (expand-file-name "emacs" state-root))))
  (add-to-list 'load-path lisp-dir)
  (add-to-list 'custom-theme-load-path
               (expand-file-name "themes" store-dir))
  ;; Keep config in the store; direct all writable state elsewhere.
  (setq user-init-file        (expand-file-name "init.el" store-dir)
        early-init-file       (expand-file-name "early-init.el" store-dir)
        user-emacs-directory  (file-name-as-directory
                               (expand-file-name "emacs" state-root))
        package-user-dir      (expand-file-name "elpa" user-emacs-directory)
        package-quickstart-file quickstart-file
        euler/package-quickstart-stamp-file (concat quickstart-file ".stamp"))
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
                  (cons state-eln-cache (nreverse kept-native-paths))))))
  (setq euler/package-quickstart-stamp (euler/package-quickstart--stamp-value)
        package-quickstart (euler/package-quickstart-valid-p)))

(add-hook 'emacs-startup-hook
          (lambda ()
            (run-with-idle-timer 2 nil #'euler/package-quickstart-refresh-maybe)))

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
