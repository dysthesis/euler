;;; -*- lexical-binding: t; -*-
(defun euler/find-if (predicate sequence)
  "Return the first item in SEQUENCE for which PREDICATE is non-nil."
  (catch 'found
    (dolist (item sequence)
      (when (funcall predicate item)
        (throw 'found item)))
    nil))

(defun euler/some (predicate sequence)
  "Return the first non-nil PREDICATE result for an item in SEQUENCE."
  (catch 'found
    (dolist (item sequence)
      (let ((result (funcall predicate item)))
        (when result
          (throw 'found result))))
    nil))

(defun euler/remove-if (predicate sequence)
  "Return a copy of SEQUENCE without items matching PREDICATE."
  (let (result)
    (dolist (item sequence (nreverse result))
      (unless (funcall predicate item)
        (push item result)))))

(defun euler/sequence-empty-p (sequence)
  "Return non-nil when SEQUENCE has no elements."
  (if (listp sequence)
      (null sequence)
    (= (length sequence) 0)))

(defun euler/string-join (strings separator)
  "Join STRINGS with SEPARATOR."
  (mapconcat #'identity strings separator))

(defun euler/string-empty-p (string)
  "Return non-nil when STRING is empty."
  (= (length string) 0))

(defun euler/string-blank-p (string)
  "Return non-nil when STRING contains only whitespace."
  (string-match-p "\\`[[:space:]]*\\'" string))

(defun euler/string-trim (string)
  "Return STRING without leading or trailing whitespace."
  (replace-regexp-in-string "\\`[[:space:]]+\\|[[:space:]]+\\'" "" string))

(provide 'core/lib)
