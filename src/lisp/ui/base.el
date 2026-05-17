;;; -*- lexical-binding: t; -*-
(load-theme 'noir t) ;; My own custom theme
(use-package solaire-mode
  :ensure t
  :config (solaire-global-mode +1))

(use-package indent-bars
  :ensure t
  :unless noninteractive
  :hook (prog-mode . indent-bars-mode)
  :config
  (setq indent-bars-treesit-support t
	indent-bars-treesit-wrap '((python argument_list parameters
					   list list_comprehension
					   dictionary dictionary_comprehension
					   parenthesized_expression subscript)
				   (c argument_list parameter_list
				      init_declarator parenthesized_expression)
				   (rust trait_item impl_item 
					 macro_definition macro_invocation 
					 struct_item enum_item mod_item 
					 const_item let_declaration 
					 function_item for_expression 
					 if_expression loop_expression 
					 while_expression match_expression 
					 match_arm call_expression 
					 token_tree token_tree_pattern
					 arguments parameters
					 token_repetition)
				   (toml table array comment)
				   (yaml block_mapping_pair comment))
        indent-bars-prefer-character
        (or
         ;; Bitmaps are far slower on MacOS, inexplicably, but this needs more
         ;; testing to see if it's specific to ns or emacs-mac builds, or is
         ;; just a general MacOS issue.
         (featurep :system 'macos)
         ;; FIX: A bitmap init bug in emacs-pgtk (before v30) could cause
         ;; crashes (see jdtsmith/indent-bars#3).
         (and (featurep 'pgtk)
              (< emacs-major-version 30)))
	;; Show indent guides starting from the first column.
        indent-bars-starting-column 0
        ;; Make indent guides subtle; the default is too distractingly colorful.
        indent-bars-width-frac 0.15  ; make bitmaps thinner
        indent-bars-color-by-depth nil
        indent-bars-color '(font-lock-comment-face :face-bg nil :blend 0.425)
        ;; Don't highlight current level indentation; it's distracting and is
        ;; unnecessary overhead for little benefit.
        indent-bars-highlight-current-depth nil
        ;; The default is `t', which shows indent-bars even on blank lines
        ;; beyond the end of an indented block. Setting it to `nil' will cause
        ;; gaps in the indent guides, which looks odd. `least' is a good
        ;; compromise, and doesn't suffer the scrolling issue.
        indent-bars-display-on-blank-lines 'least))

(use-package ligature
  :ensure t
  :config
  ;; Enable the "www" ligature in every possible major mode
  (ligature-set-ligatures 't '("www"))
  ;; Enable traditional text ligatures in prose and documentation modes.
  (ligature-set-ligatures '(eww-mode org-mode markdown-mode help-mode Info-mode Man-mode woman-mode)
                          '("ff" "fi" "fl" "ffi" "ffl"))
  ;; Enable programming ligatures in programming modes.
  (ligature-set-ligatures '(prog-mode typst-ts-mode)
			  '("|||>" "<|||" "<==>" "<!--" "####" "~~>" "***" "||=" "||>"
			    ":::" "::=" "=:=" "===" "==>" "=!=" "=>>" "=<<" "=/=" "!=="
			    "!!." ">=>" ">>=" ">>>" ">>-" ">->" "->>" "-->" "---" "-<<"
			    "<~~" "<~>" "<*>" "<||" "<|>" "<$>" "<==" "<=>" "<=<" "<->"
			    "<--" "<-<" "<<=" "<<-" "<<<" "<+>" "</>" "###" "#_(" "..<"
			    "..." "+++" "/==" "///" "_|_" "www" "&&" "^=" "~~" "~@" "~="
			    "~>" "~-" "**" "*>" "*/" "||" "|}" "|]" "|=" "|>" "|-" "{|"
			    "[|" "]#" "::" ":=" ":>" ":<" "$>" "==" "=>" "!=" "!!" ">:"
			    ">=" ">>" ">-" "-~" "-|" "->" "--" "-<" "<~" "<*" "<|" "<:"
			    "<$" "<=" "<>" "<-" "<<" "<+" "</" "#{" "#[" "#:" "#=" "#!"
			    "##" "#(" "#?" "#_" "%%" ".=" ".-" ".." ".?" "+>" "++" "?:"
			    "?=" "?." "??" ";;" "/*" "/=" "/>" "//" "__" "~~" "(*" "*)"
			    "\\\\" "://"))
  ;; Enables ligature checks globally in all buffers.  You can also do it
  ;; per mode with `ligature-mode'.
  (global-ligature-mode t))

(use-package hl-todo
  :ensure t
  :hook (prog-mode . global-hl-todo-mode)
  :config
  (setq hl-todo-highlight-punctuation ":"
	;; Don't highlight todo keywords in text-mode derivatives unless in
        ;; comments (e.g. data formats like yaml, json, etc).
        hl-todo-text-modes nil
	hl-todo-keyword-faces
        '(;; For reminders to change or add something at a later date.
          ("TODO" warning bold)
          ;; For code (or code paths) that are broken, unimplemented, or slow,
          ;; and may become bigger problems later.
          ("FIXME" error bold)
          ;; For code that needs to be revisited later, either to upstream it,
          ;; improve it, or address non-critical issues.
          ("REVIEW" font-lock-keyword-face bold)
          ;; For code smells where questionable practices are used intentionally
          ;; and is likely to break in a future update.
          ("HACK" font-lock-constant-face bold)
          ;; For sections of code that just gotta go, and will be gone soon.
          ;; Specifically, this means the code is deprecated, not necessarily
          ;; the feature it enables.
          ("DEPRECATED" font-lock-doc-face bold)
          ;; Extra keywords commonly found in the wild, whose meaning may vary
          ;; from project to project. Doom doesn't use BUG.
          ("BUG" error bold)
	  ;; Performance tricks
	  ("PERF" font-lock-constant-face bold)
          ;; Doom uses NOTE to indicate either A) this comment is about a code
          ;; omission, e.g. "I *would've* put X here, but I didn't because Y",
          ;; or B) it's a comment about a large section of code beyond the scope
          ;; of adjacent lines.
          ("NOTE" success bold))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Tab-bar configuration
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Show the tab-bar as soon as tab-bar functions are invoked
(setopt tab-bar-show 1)

;; Add the time to the tab-bar, if visible
(add-to-list 'tab-bar-format 'tab-bar-format-align-right 'append)
(add-to-list 'tab-bar-format 'tab-bar-format-global 'append)
(setopt display-time-format "%a %F %T")
(setopt display-time-interval 60)
(display-time-mode) 

(provide 'ui/base)
