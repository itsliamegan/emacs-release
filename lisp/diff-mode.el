;;; diff-mode.el --- a mode for viewing/editing context diffs
;; Copyright (C) 1998, 1999, 2000, 2001, 2002, 2003, 2004,
;;   2005, 2006, 2007, 2008, 2009 Free Software Foundation, Inc.
;; Author: Stefan Monnier <monnier@iro.umontreal.ca>
;; Keywords: convenience patch diff
;; GNU Emacs is free software: you can redistribute it and/or modify
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;; Inspired by Pavel Machek's patch-mode.el (<pavel@@atrey.karlin.mff.cuni.cz>)
;; Some efforts were spent to have it somewhat compatible with XEmacs'
;; - Improve `diff-add-change-log-entries-other-window',
;;   it is very simplistic now.
;;
;; - Add a `delete-after-apply' so C-c C-a automatically deletes hunks.
;;   Also allow C-c C-a to delete already-applied hunks.
;;
;; - Try `diff <file> <hunk>' to try and fuzzily discover the source location
;;   of a hunk.  Show then the changes between <file> and <hunk> and make it
;;   possible to apply them to <file>, <hunk-src>, or <hunk-dst>.
;;   Or maybe just make it into a ".rej to diff3-markers converter".
;;   Maybe just use `wiggle' (by Neil Brown) to do it for us.
;;
;; - in diff-apply-hunk, strip context in replace-match to better
;;   preserve markers and spacing.
(defvar add-log-buffer-file-name-function)

  "Major mode for viewing/editing diffs."
(defcustom diff-default-read-only nil
  "Non-nil means `diff-goto-source' jumps to the old file.
  :type 'boolean
  :group 'diff-mode)
  "Non-nil means hunk headers are kept up-to-date on-the-fly.
  :type 'boolean
  :group 'diff-mode)
  "Non-nil means `diff-apply-hunk' will move to the next hunk after applying."
  :type 'boolean
  :group 'diff-mode)
(defcustom diff-mode-hook nil
  "Run after setting up the `diff-mode' major mode."
  :type 'hook
  :options '(diff-delete-empty-files diff-make-unified)
  :group 'diff-mode)
    ("\t" . diff-hunk-next)
    ([backtab] . diff-hunk-prev)
    ([mouse-2] . diff-goto-source)
    ;; Standard M-w is useful, so don't change M-W.
    ;;("W" . widen)
    ;; Not useful if you have to metafy them.
    ;;(" " . scroll-up)
    ;;("\177" . scroll-down)
    ;; Standard M-a is useful, so don't change M-A.
    ;;("A" . diff-ediff-patch)
    ;; Standard M-r is useful, so don't change M-r or M-R.
    ;;("r" . diff-restrict-view)
    ;;("R" . diff-reverse-direction)
    ("q" . quit-window))
    ;; By analogy with the global C-x 4 a binding.
    ("\C-x4A" . diff-add-change-log-entries-other-window)
    ("\C-c\C-e" . diff-ediff-patch)
    ("\C-c\C-n" . diff-restrict-view)
    ("\C-c\C-s" . diff-split-hunk)
    ("\C-c\C-t" . diff-test-hunk)
    ("\C-c\C-r" . diff-reverse-direction)
    ("\C-c\C-u" . diff-context->unified)
    ;; `d' because it duplicates the context :-(  --Stef
    ("\C-c\C-d" . diff-unified->context)
    ("\C-c\C-w" . diff-ignore-whitespace-hunk)
    ("\C-c\C-b" . diff-refine-hunk)  ;No reason for `b' :-(
    ("\C-c\C-f" . next-error-follow-minor-mode))
    ["Jump to Source"		diff-goto-source
     :help "Jump to the corresponding source line"]
    ["Apply hunk"		diff-apply-hunk
     :help "Apply the current hunk to the source file and go to the next"]
    ["Test applying hunk"	diff-test-hunk
     :help "See whether it's possible to apply the current hunk"]
    ["Apply diff with Ediff"	diff-ediff-patch
     :help "Call `ediff-patch-file' on the current buffer"]
    ["Create Change Log entries" diff-add-change-log-entries-other-window
     :help "Create ChangeLog entries for the changes in the diff buffer"]
    "-----"
    ["Reverse direction"	diff-reverse-direction
     :help "Reverse the direction of the diffs"]
    ["Context -> Unified"	diff-context->unified
     :help "Convert context diffs to unified diffs"]
    ["Unified -> Context"	diff-unified->context
     :help "Convert unified diffs to context diffs"]
    ["Show trailing whitespace" whitespace-mode
     :style toggle :selected (bound-and-true-p whitespace-mode)
     :help "Show trailing whitespace in modified lines"]
    "-----"
    ["Split hunk"		diff-split-hunk
     :active (diff-splittable-p)
     :help "Split the current (unified diff) hunk at point into two hunks"]
    ["Ignore whitespace changes" diff-ignore-whitespace-hunk
     :help "Re-diff the current hunk, ignoring whitespace differences"]
    ["Highlight fine changes"	diff-refine-hunk
     :help "Highlight changes of hunk at point at a finer granularity"]
    ["Kill current hunk"	diff-hunk-kill
     :help "Kill current hunk"]
    ["Kill current file's hunks" diff-file-kill
     :help "Kill all current file's hunks"]
    "-----"
    ["Previous Hunk"		diff-hunk-prev
     :help "Go to the previous count'th hunk"]
    ["Next Hunk"		diff-hunk-next
     :help "Go to the next count'th hunk"]
    ["Previous File"		diff-file-prev
     :help "Go to the previous count'th file"]
    ["Next File"		diff-file-next
     :help "Go to the next count'th file"]
  :type '(choice (string "\e") (string "C-c=") string)
  :group 'diff-mode)
(define-minor-mode diff-auto-refine-mode
  "Automatically highlight changes in detail as the user visits hunks.
When transitioning from disabled to enabled,
try to refine the current hunk, as well."
  :group 'diff-mode :init-value t :lighter nil ;; " Auto-Refine"
  (when diff-auto-refine-mode
    (condition-case-no-debug nil (diff-refine-hunk) (error nil))))
(defface diff-header
  '((((class color) (min-colors 88) (background light))
     :background "grey80")
    (((class color) (min-colors 88) (background dark))
     :background "grey45")
     :foreground "blue1" :weight bold)
     :foreground "green" :weight bold)
    (t :weight bold))
;; backward-compatibility alias
(put 'diff-header-face 'face-alias 'diff-header)
(defvar diff-header-face 'diff-header)

(defface diff-file-header
  '((((class color) (min-colors 88) (background light))
     :background "grey70" :weight bold)
    (((class color) (min-colors 88) (background dark))
     :background "grey60" :weight bold)
     :foreground "green" :weight bold)
     :foreground "cyan" :weight bold)
    (t :weight bold))			; :height 1.3
;; backward-compatibility alias
(put 'diff-file-header-face 'face-alias 'diff-file-header)
(defvar diff-file-header-face 'diff-file-header)
(defface diff-index
  '((t :inherit diff-file-header))
;; backward-compatibility alias
(put 'diff-index-face 'face-alias 'diff-index)
(defvar diff-index-face 'diff-index)
(defface diff-hunk-header
  '((t :inherit diff-header))
;; backward-compatibility alias
(put 'diff-hunk-header-face 'face-alias 'diff-hunk-header)
(defvar diff-hunk-header-face 'diff-hunk-header)
(defface diff-removed
  '((t :inherit diff-changed))
;; backward-compatibility alias
(put 'diff-removed-face 'face-alias 'diff-removed)
(defvar diff-removed-face 'diff-removed)
(defface diff-added
  '((t :inherit diff-changed))
;; backward-compatibility alias
(put 'diff-added-face 'face-alias 'diff-added)
(defvar diff-added-face 'diff-added)
(defface diff-changed
     :foreground "magenta" :weight bold :slant italic)
     :foreground "yellow" :weight bold :slant italic))
;; backward-compatibility alias
(put 'diff-changed-face 'face-alias 'diff-changed)
(defvar diff-changed-face 'diff-changed)

(defface diff-indicator-removed
  '((t :inherit diff-removed))
  "`diff-mode' face used to highlight indicator of removed lines (-, <)."
  :group 'diff-mode
  :version "22.1")
(defvar diff-indicator-removed-face 'diff-indicator-removed)
(defface diff-indicator-added
  '((t :inherit diff-added))
  "`diff-mode' face used to highlight indicator of added lines (+, >)."
  :group 'diff-mode
  :version "22.1")
(defvar diff-indicator-added-face 'diff-indicator-added)

(defface diff-indicator-changed
  '((t :inherit diff-changed))
  "`diff-mode' face used to highlight indicator of changed lines."
  :group 'diff-mode
  :version "22.1")
(defvar diff-indicator-changed-face 'diff-indicator-changed)

(defface diff-function
  '((t :inherit diff-header))
;; backward-compatibility alias
(put 'diff-function-face 'face-alias 'diff-function)
(defvar diff-function-face 'diff-function)
(defface diff-context
  '((((class color grayscale) (min-colors 88)) :inherit shadow))
;; backward-compatibility alias
(put 'diff-context-face 'face-alias 'diff-context)
(defvar diff-context-face 'diff-context)
(defface diff-nonexistent
  '((t :inherit diff-file-header))
;; backward-compatibility alias
(put 'diff-nonexistent-face 'face-alias 'diff-nonexistent)
(defvar diff-nonexistent-face 'diff-nonexistent)

(defconst diff-yank-handler '(diff-yank-function))
(defun diff-yank-function (text)
  ;; FIXME: the yank-handler is now called separately on each piece of text
  ;; with a yank-handler property, so the next-single-property-change call
  ;; below will always return nil :-(   --stef
  (let ((mixed (next-single-property-change 0 'yank-handler text))
	(start (point)))
    ;; First insert the text.
    (insert text)
    ;; If the text does not include any diff markers and if we're not
    ;; yanking back into a diff-mode buffer, get rid of the prefixes.
    (unless (or mixed (derived-mode-p 'diff-mode))
      (undo-boundary)		; Just in case the user wanted the prefixes.
      (let ((re (save-excursion
		  (if (re-search-backward "^[><!][ \t]" start t)
		      (if (eq (char-after) ?!)
			  "^[!+- ][ \t]" "^[<>][ \t]")
		    "^[ <>!+-]"))))
	(save-excursion
	  (while (re-search-backward re start t)
	    (replace-match "" t t)))))))

(defconst diff-hunk-header-re-unified
  "^@@ -\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? \\+\\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? @@")
(defconst diff-context-mid-hunk-header-re
  "--- \\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? ----$")
  `((,(concat "\\(" diff-hunk-header-re-unified "\\)\\(.*\\)$")
     (1 diff-hunk-header-face) (6 diff-function-face))
    ("^\\(\\*\\{15\\}\\)\\(.*\\)$"                        ;context
     (1 diff-hunk-header-face) (2 diff-function-face))
    (,diff-context-mid-hunk-header-re . diff-hunk-header-face) ;context
    ("^[0-9,]+[acd][0-9,]+$"     . diff-hunk-header-face) ;normal
    ("^---$"                     . diff-hunk-header-face) ;normal
    ;; For file headers, accept files with spaces, but be careful to rule
    ;; out false-positives when matching hunk headers.
    ("^\\(---\\|\\+\\+\\+\\|\\*\\*\\*\\) \\([^\t\n]+?\\)\\(?:\t.*\\| \\(\\*\\*\\*\\*\\|----\\)\\)?\n"
     (0 diff-header-face)
     (2 (if (not (match-end 3)) diff-file-header-face) prepend))
    ("^\\([-<]\\)\\(.*\n\\)"
     (1 diff-indicator-removed-face) (2 diff-removed-face))
    ("^\\([+>]\\)\\(.*\n\\)"
     (1 diff-indicator-added-face) (2 diff-added-face))
    ("^\\(!\\)\\(.*\n\\)"
     (1 diff-indicator-changed-face) (2 diff-changed-face))
    ("^Index: \\(.+\\).*\n"
     (0 diff-header-face) (1 diff-index-face prepend))
    ("^\\(#\\)\\(.*\\)"
     (1 font-lock-comment-delimiter-face)
     (2 font-lock-comment-face))
    ("^[^-=+*!<>#].*\n" (0 diff-context-face))))
(defvar diff-valid-unified-empty-line t
  "If non-nil, empty lines are valid in unified diffs.
Some versions of diff replace all-blank context lines in unified format with
empty lines.  This makes the format less robust, but is tolerated.
See http://lists.gnu.org/archive/html/emacs-devel/2007-11/msg01990.html")

(defconst diff-hunk-header-re
  (concat "^\\(?:" diff-hunk-header-re-unified ".*\\|\\*\\{15\\}.*\n\\*\\*\\* .+ \\*\\*\\*\\*\\|[0-9]+\\(,[0-9]+\\)?[acd][0-9]+\\(,[0-9]+\\)?\\)$"))
(defconst diff-file-header-re (concat "^\\(--- .+\n\\+\\+\\+ \\|\\*\\*\\* .+\n--- \\|[^-+!<>0-9@* \n]\\).+\n" (substring diff-hunk-header-re 1)))
(defun diff-hunk-style (&optional style)
  (when (looking-at diff-hunk-header-re)
    (setq style (cdr (assq (char-after) '((?@ . unified) (?* . context)))))
    (goto-char (match-end 0)))
  style)

(defun diff-end-of-hunk (&optional style donttrustheader)
  (let (end)
    (when (looking-at diff-hunk-header-re)
      ;; Especially important for unified (because headers are ambiguous).
      (setq style (diff-hunk-style style))
      (goto-char (match-end 0))
      (when (and (not donttrustheader) (match-end 2))
        (let* ((nold (string-to-number (or (match-string 2) "1")))
               (nnew (string-to-number (or (match-string 4) "1")))
               (endold
        (save-excursion
          (re-search-forward (if diff-valid-unified-empty-line
                                 "^[- \n]" "^[- ]")
                                     nil t nold)
                  (line-beginning-position 2)))
               (endnew
                ;; The hunk may end with a bunch of "+" lines, so the `end' is
                ;; then further than computed above.
                (save-excursion
                  (re-search-forward (if diff-valid-unified-empty-line
                                         "^[+ \n]" "^[+ ]")
                                     nil t nnew)
                  (line-beginning-position 2))))
          (setq end (max endold endnew)))))
    ;; We may have a first evaluation of `end' thanks to the hunk header.
    (unless end
      (setq end (and (re-search-forward
                      (case style
                        (unified (concat (if diff-valid-unified-empty-line
                                             "^[^-+# \\\n]\\|" "^[^-+# \\]\\|")
                                         ;; A `unified' header is ambiguous.
                                         diff-file-header-re))
                        (context "^[^-+#! \\]")
                        (normal "^[^<>#\\]")
                        (t "^[^-+#!<> \\]"))
                      nil t)
                     (match-beginning 0)))
      (when diff-valid-unified-empty-line
        ;; While empty lines may be valid inside hunks, they are also likely
        ;; to be unrelated to the hunk.
        (goto-char (or end (point-max)))
        (while (eq ?\n (char-before (1- (point))))
          (forward-char -1)
          (setq end (point)))))
(defun diff-beginning-of-hunk (&optional try-harder)
  "Move back to beginning of hunk.
If TRY-HARDER is non-nil, try to cater to the case where we're not in a hunk
but in the file header instead, in which case move forward to the first hunk."
      (error
       (if (not try-harder)
           (error "Can't find the beginning of the hunk")
         (diff-beginning-of-file-and-junk)
         (diff-hunk-next))))))

(defun diff-unified-hunk-p ()
  (save-excursion
    (ignore-errors
      (diff-beginning-of-hunk)
      (looking-at "^@@"))))
    (let ((start (point))
          res)
      ;; diff-file-header-re may need to match up to 4 lines, so in case
      ;; we're inside the header, we need to move up to 3 lines forward.
      (forward-line 3)
      (if (and (setq res (re-search-backward diff-file-header-re nil t))
               ;; Maybe the 3 lines forward were too much and we matched
               ;; a file header after our starting point :-(
               (or (<= (point) start)
                   (setq res (re-search-backward diff-file-header-re nil t))))
          res
        (goto-char start)
        (error "Can't find the beginning of the file")))))

  (re-search-forward (concat "^[^-+#!<>0-9@* \\]\\|" diff-file-header-re)
		     nil 'move)
  (if (match-beginning 1)
      (goto-char (match-beginning 1))
    (beginning-of-line)))
 diff-hunk diff-hunk-header-re "hunk" diff-end-of-hunk diff-restrict-view
 (if diff-auto-refine-mode
     (condition-case-no-debug nil (diff-refine-hunk) (error nil))))

    (if arg (diff-beginning-of-file) (diff-beginning-of-hunk 'try-harder))
  (let* ((start (point))
	 (nexthunk (when (re-search-forward diff-hunk-header-re nil t)
		     (match-beginning 0)))
	 (firsthunk (ignore-errors
		      (goto-char start)
		      (diff-beginning-of-file) (diff-hunk-next) (point)))
	 (nextfile (ignore-errors (diff-file-next) (point)))
	 (inhibit-read-only t))
    (goto-char start)
	;; It's the only hunk for this file, so kill the file.
;; "index ", "old mode", "new mode", "new file mode" and
;; "deleted file mode" are output by git-diff.
(defconst diff-file-junk-re
  "diff \\|index \\|\\(?:deleted file\\|new\\(?: file\\)?\\|old\\) mode")

(defun diff-beginning-of-file-and-junk ()
  "Go to the beginning of file-related diff-info.
This is like `diff-beginning-of-file' except it tries to skip back over leading
data such as \"Index: ...\" and such."
  (let* ((orig (point))
         ;; Skip forward over what might be "leading junk" so as to get
         ;; closer to the actual diff.
         (_ (progn (beginning-of-line)
                   (while (looking-at diff-file-junk-re)
                     (forward-line 1))))
         (start (point))
         (prevfile (condition-case err
                       (save-excursion (diff-beginning-of-file) (point))
                     (error err)))
         (err (if (consp prevfile) prevfile))
         (nextfile (ignore-errors
                     (save-excursion
                       (goto-char start) (diff-file-next) (point))))
         ;; prevhunk is one of the limits.
         (prevhunk (save-excursion
                     (ignore-errors
                       (if (numberp prevfile) (goto-char prevfile))
                       (diff-hunk-prev) (point))))
         (previndex (save-excursion
                      (forward-line 1)  ;In case we're looking at "Index:".
                      (re-search-backward "^Index: " prevhunk t))))
    ;; If we're in the junk, we should use nextfile instead of prevfile.
    (if (and (numberp nextfile)
             (or (not (numberp prevfile))
                 (and previndex (> previndex prevfile))))
        (setq prevfile nextfile))
    (if (and previndex (numberp prevfile) (< previndex prevfile))
        (setq prevfile previndex))
    (if (and (numberp prevfile) (<= prevfile start))
          (progn
            (goto-char prevfile)
            ;; Now skip backward over the leading junk we may have before the
            ;; diff itself.
            (while (save-excursion
                     (and (zerop (forward-line -1))
                          (looking-at diff-file-junk-re)))
              (forward-line -1)))
      ;; File starts *after* the starting point: we really weren't in
      ;; a file diff but elsewhere.
      (goto-char orig)
      (signal (car err) (cdr err)))))

  (let ((orig (point))
        (start (progn (diff-beginning-of-file-and-junk) (point)))
	 (inhibit-read-only t))
    (if (looking-at "^\n") (forward-char 1)) ;`tla' generates such diffs.
    (if (> orig (point)) (error "Not inside a file diff"))
(defun diff-splittable-p ()
  (save-excursion
    (beginning-of-line)
    (and (looking-at "^[-+ ]")
         (progn (forward-line -1) (looking-at "^[-+ ]"))
         (diff-unified-hunk-p))))

    (unless (looking-at diff-hunk-header-re-unified)
	   (start2 (string-to-number (match-string 3)))
	   (newstart2 (+ start2 (diff-count-matches "^[+ \t]" (point) pos)))
	   (inhibit-read-only t))

(defvar diff-remembered-defdir nil)
(defun diff-tell-file-name (old name)
  "Tell Emacs where the find the source file of the current hunk.
If the OLD prefix arg is passed, tell the file NAME of the old file."
  (interactive
   (let* ((old current-prefix-arg)
	  (fs (diff-hunk-file-names current-prefix-arg)))
     (unless fs (error "No file name to look for"))
     (list old (read-file-name (format "File for %s: " (car fs))
			       nil (diff-find-file-name old 'noprompt) t))))
  (let ((fs (diff-hunk-file-names old)))
    (unless fs (error "No file name to look for"))
    (push (cons fs name) diff-remembered-files-alist)))

(defun diff-hunk-file-names (&optional old)
  "Give the list of file names textually mentioned for the current hunk."
    (let ((limit (save-excursion
	  (header-files
	   (if (looking-at "[-*][-*][-*] \\(\\S-+\\)\\(\\s-.*\\)?\n[-+][-+][-+] \\(\\S-+\\)")
	       (list (if old (match-string 1) (match-string 3))
		     (if old (match-string 3) (match-string 1)))
	     (forward-line 1) nil)))
      (delq nil
	    (append
	     (when (and (not old)
			(save-excursion
			  (re-search-backward "^Index: \\(.+\\)" limit t)))
	       (list (match-string 1)))
	     header-files
	     (when (re-search-backward
		    "^diff \\(-\\S-+ +\\)*\\(\\S-+\\)\\( +\\(\\S-+\\)\\)?"
		    nil t)
	       (list (if old (match-string 2) (match-string 4))
		     (if old (match-string 4) (match-string 2)))))))))

(defun diff-find-file-name (&optional old noprompt prefix)
  "Return the file corresponding to the current patch.
Non-nil OLD means that we want the old file.
Non-nil NOPROMPT means to prefer returning nil than to prompt the user.
PREFIX is only used internally: don't use it."
  (unless (equal diff-remembered-defdir default-directory)
    ;; Flush diff-remembered-files-alist if the default-directory is changed.
    (set (make-local-variable 'diff-remembered-defdir) default-directory)
    (set (make-local-variable 'diff-remembered-files-alist) nil))
  (save-excursion
    (unless (looking-at diff-file-header-re)
      (or (ignore-errors (diff-beginning-of-file))
	  (re-search-forward diff-file-header-re nil t)))
    (let ((fs (diff-hunk-file-names old)))
      (if prefix (setq fs (mapcar (lambda (f) (concat prefix f)) fs)))
			       ;; Use file-regular-p to avoid
			       ;; /dev/null, directories, etc.
			       ((or (null file) (file-regular-p file))
       ;; If we haven't found the file, maybe it's because we haven't paid
       ;; attention to the PCL-CVS hint.
       (and (not prefix)
	    (boundp 'cvs-pcl-cvs-dirchange-re)
	    (save-excursion
	      (re-search-backward cvs-pcl-cvs-dirchange-re nil t))
	    (diff-find-file-name old noprompt (match-string 1)))
       (unless noprompt
         (let ((file (read-file-name (format "Use file %s: "
                                             (or (first fs) ""))
                                     nil (first fs) t (first fs))))
           (set (make-local-variable 'diff-remembered-files-alist)
                (cons (cons fs file) diff-remembered-files-alist))
           file))))))
;;;;
;;;;
else cover the whole buffer."
  (interactive (if (or current-prefix-arg (and transient-mark-mode mark-active))
		   (list (region-beginning) (region-end))
  (unless (markerp end) (setq end (copy-marker end t)))
      (while (and (re-search-forward
                   (concat "^\\(\\(---\\) .+\n\\(\\+\\+\\+\\) .+\\|"
                           diff-hunk-header-re-unified ".*\\)$")
                   nil t)
		  (lines1 (or (match-string 5) "1"))
		  (lines2 (or (match-string 7) "1"))
		  ;; Variables to use the special undo function.
		  (old-undo buffer-undo-list)
		  (old-end (marker-position end))
		  (start (match-beginning 0))
		  (reversible t))
					    -1))
		       " ****"))
		(narrow-to-region (line-beginning-position 2)
                                  ;; Call diff-end-of-hunk from just before
                                  ;; the hunk header so it can use the hunk
                                  ;; header info.
			  (?\s (insert " ") (setq modif nil) (backward-char 1))
                          ;; diff-valid-unified-empty-line.
                          (?\n (insert "  ") (setq modif nil) (backward-char 2))
						 -1))
                            " ----\n" hunk))
		      (if (save-excursion (re-search-forward "^\\+.*\n-" nil t))
                          ;; Normally, lines in a substitution come with
                          ;; first the removals and then the additions, and
                          ;; the context->unified function follows this
                          ;; convention, of course.  Yet, other alternatives
                          ;; are valid as well, but they preclude the use of
                          ;; context->unified as an undo command.
			  (setq reversible nil))
			  (?\s (insert " ") (setq modif nil) (backward-char 1))
                          ;; diff-valid-unified-empty-line.
                          (?\n (insert "  ") (setq modif nil) (backward-char 2)
                               (setq reversible nil))
			    (setq delete nil)))))))
		(unless (or (not reversible) (eq buffer-undo-list t))
                  ;; Drop the many undo entries and replace them with
                  ;; a single entry that uses diff-context->unified to do
                  ;; the work.
		  (setq buffer-undo-list
			(cons (list 'apply (- old-end end) start (point-max)
				    'diff-context->unified start (point-max))
			      old-undo)))))))))))

(defun diff-context->unified (start end &optional to-context)
START and END are either taken from the region
\(when it is highlighted) or else cover the whole buffer.
With a prefix argument, convert unified format to context format."
  (interactive (if (and transient-mark-mode mark-active)
		   (list (region-beginning) (region-end) current-prefix-arg)
		 (list (point-min) (point-max) current-prefix-arg)))
  (if to-context
      (diff-unified->context start end)
    (unless (markerp end) (setq end (copy-marker end t)))
    (let ( ;;(diff-inhibit-after-change t)
          (inhibit-read-only t))
      (save-excursion
        (goto-char start)
        (while (and (re-search-forward "^\\(\\(\\*\\*\\*\\) .+\n\\(---\\) .+\\|\\*\\{15\\}.*\n\\*\\*\\* \\([0-9]+\\),\\(-?[0-9]+\\) \\*\\*\\*\\*\\)$" nil t)
                    (< (point) end))
          (combine-after-change-calls
            (if (match-beginning 2)
                ;; we matched a file header
                (progn
                  ;; use reverse order to make sure the indices are kept valid
                  (replace-match "+++" t t nil 3)
                  (replace-match "---" t t nil 2))
              ;; we matched a hunk header
              (let ((line1s (match-string 4))
                    (line1e (match-string 5))
                    (pt1 (match-beginning 0))
                    ;; Variables to use the special undo function.
                    (old-undo buffer-undo-list)
                    (old-end (marker-position end))
                    (reversible t))
                (replace-match "")
                (unless (re-search-forward
                         diff-context-mid-hunk-header-re nil t)
                  (error "Can't find matching `--- n1,n2 ----' line"))
                (let ((line2s (match-string 1))
                      (line2e (match-string 2))
                      (pt2 (progn
                             (delete-region (progn (beginning-of-line) (point))
                                            (progn (forward-line 1) (point)))
                             (point-marker))))
                  (goto-char pt1)
                  (forward-line 1)
                  (while (< (point) pt2)
                    (case (char-after)
                      (?! (delete-char 2) (insert "-") (forward-line 1))
                      (?- (forward-char 1) (delete-char 1) (forward-line 1))
                      (?\s           ;merge with the other half of the chunk
                       (let* ((endline2
                               (save-excursion
                                 (goto-char pt2) (forward-line 1) (point))))
                         (case (char-after pt2)
                           ((?! ?+)
                            (insert "+"
                                    (prog1 (buffer-substring (+ pt2 2) endline2)
                                      (delete-region pt2 endline2))))
                           (?\s
                            (unless (= (- endline2 pt2)
                                       (- (line-beginning-position 2) (point)))
                              ;; If the two lines we're merging don't have the
                              ;; same length (can happen with "diff -b"), then
                              ;; diff-unified->context will not properly undo
                              ;; this operation.
                              (setq reversible nil))
                            (delete-region pt2 endline2)
                            (delete-char 1)
                            (forward-line 1))
                           (?\\ (forward-line 1))
                           (t (setq reversible nil)
                              (delete-char 1) (forward-line 1)))))
                      (t (setq reversible nil) (forward-line 1))))
                  (while (looking-at "[+! ] ")
                    (if (/= (char-after) ?!) (forward-char 1)
                      (delete-char 1) (insert "+"))
                    (delete-char 1) (forward-line 1))
                  (save-excursion
                    (goto-char pt1)
                    (insert "@@ -" line1s ","
                            (number-to-string (- (string-to-number line1e)
                                                 (string-to-number line1s)
                                                 -1))
                            " +" line2s ","
                            (number-to-string (- (string-to-number line2e)
                                                 (string-to-number line2s)
                                                 -1)) " @@"))
                  (set-marker pt2 nil)
                  ;; The whole procedure succeeded, let's replace the myriad
                  ;; of undo elements with just a single special one.
                  (unless (or (not reversible) (eq buffer-undo-list t))
                    (setq buffer-undo-list
                          (cons (list 'apply (- old-end end) pt1 (point)
                                      'diff-unified->context pt1 (point))
                                old-undo)))
                  )))))))))
else cover the whole buffer."
  (interactive (if (or current-prefix-arg (and transient-mark-mode mark-active))
		   (list (region-beginning) (region-end))
  (unless (markerp end) (setq end (copy-marker end t)))
		  (unless (looking-at diff-context-mid-hunk-header-re)
		  (let* ((str1end (or (match-end 2) (match-end 1)))
                         (str1 (buffer-substring (match-beginning 1) str1end)))
                    (goto-char str1end)
                    (insert lines1)
                    (delete-region (match-beginning 1) str1end)
			    (insert (delete-and-extract-region first last)))
			  (memq c (if diff-valid-unified-empty-line
                                      '(?\s ?\n) '(?\s)))))
else cover the whole buffer."
  (interactive (if (or current-prefix-arg (and transient-mark-mode mark-active))
		   (list (region-beginning) (region-end))
      (goto-char end) (diff-end-of-hunk nil 'donttrustheader)
	  (if (not (looking-at
		    (concat diff-hunk-header-re-unified
			    "\\|[-*][-*][-*] [0-9,]+ [-*][-*][-*][-*]$"
			    "\\|--- .+\n\\+\\+\\+ ")))
		(?\s (incf space))
	     ((looking-at diff-hunk-header-re-unified)
	      (let* ((old1 (match-string 2))
		     (old2 (match-string 4))
                (if old2
                    (unless (string= new2 old2) (replace-match new2 t t nil 4))
                  (goto-char (match-end 4)) (insert "," new2))
                (if old1
                    (unless (string= new1 old1) (replace-match new1 t t nil 2))
                  (goto-char (match-end 2)) (insert "," new1))))
	     ((looking-at diff-context-mid-hunk-header-re)
;;;;
;;;;
		    (max end (cdr diff-unhandled-changes))))
	;; Maybe we've cut the end of the hunk before point.
	(if (and (bolp) (not (bobp))) (backward-char 1))
	;; We used to fixup modifs on all the changes, but it turns out that
	;; it's safer not to do it on big changes, e.g. when yanking a big
	;; diff, or when the user edits the header, since we might then
	;; screw up perfectly correct values.  --Stef
	(diff-beginning-of-hunk)
        (let* ((style (if (looking-at "\\*\\*\\*") 'context))
               (start (line-beginning-position (if (eq style 'context) 3 2)))
               (mid (if (eq style 'context)
                        (save-excursion
                          (re-search-forward diff-context-mid-hunk-header-re
                                             nil t)))))
          (when (and ;; Don't try to fixup changes in the hunk header.
                 (> (car diff-unhandled-changes) start)
                 ;; Don't try to fixup changes in the mid-hunk header either.
                 (or (not mid)
                     (< (cdr diff-unhandled-changes) (match-beginning 0))
                     (> (car diff-unhandled-changes) (match-end 0)))
                 (save-excursion
		(diff-end-of-hunk nil 'donttrustheader)
                   ;; Don't try to fixup changes past the end of the hunk.
                   (>= (point) (cdr diff-unhandled-changes))))
	  (diff-fixup-modifs (point) (cdr diff-unhandled-changes)))))
      (setq diff-unhandled-changes nil))))

(defun diff-next-error (arg reset)
  ;; Select a window that displays the current buffer so that point
  ;; movements are reflected in that window.  Otherwise, the user might
  ;; never see the hunk corresponding to the source she's jumping to.
  (pop-to-buffer (current-buffer))
  (if reset (goto-char (point-min)))
  (diff-hunk-next arg)
  (diff-goto-source))

(defvar whitespace-style)
(defvar whitespace-trailing-regexp)

When the buffer is read-only, the ESC prefix is not necessary.
If you edit the buffer manually, diff-mode will try to update the hunk
headers for you on-the-fly.

You can also switch between context diff and unified diff with \\[diff-context->unified],
or vice versa with \\[diff-unified->context] and you can also reverse the direction of
a diff with \\[diff-reverse-direction].

   \\{diff-mode-map}"

  (set (make-local-variable 'next-error-function) 'diff-next-error)

  (set (make-local-variable 'beginning-of-defun-function)
       'diff-beginning-of-file-and-junk)
  (set (make-local-variable 'end-of-defun-function)
       'diff-end-of-file)

  ;; Set up `whitespace-mode' so that turning it on will show trailing
  ;; whitespace problems on the modified lines of the diff.
  (set (make-local-variable 'whitespace-style) '(trailing))
  (set (make-local-variable 'whitespace-trailing-regexp)
       "^[-\+!<>].*?\\([\t ]+\\)$")
  (setq buffer-read-only diff-default-read-only)
      (add-hook 'write-contents-functions 'diff-write-contents-hooks nil t)
  (lexical-let ((ro-bind (cons 'buffer-read-only diff-mode-shared-map)))
    (add-to-list 'minor-mode-overriding-map-alist ro-bind)
    ;; Turn off this little trick in case the buffer is put in view-mode.
    (add-hook 'view-mode-hook
	      (lambda ()
		(setq minor-mode-overriding-map-alist
		      (delq ro-bind minor-mode-overriding-map-alist)))
	      nil t))
       (lambda () (diff-find-file-name nil 'noprompt))))
  :group 'diff-mode :lighter " Diff"
      (add-hook 'write-contents-functions 'diff-write-contents-hooks nil t)
;;; Handy hook functions ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun diff-delete-if-empty ()
  ;; An empty diff file means there's no more diffs to integrate, so we
  ;; can just remove the file altogether.  Very handy for .rej files if we
  ;; remove hunks as we apply them.
  (when (and buffer-file-name
	     (eq 0 (nth 7 (file-attributes buffer-file-name))))
    (delete-file buffer-file-name)))

(defun diff-delete-empty-files ()
  "Arrange for empty diff files to be removed."
  (add-hook 'after-save-hook 'diff-delete-if-empty nil t))

(defun diff-make-unified ()
  "Turn context diffs into unified diffs if applicable."
  (if (save-excursion
	(goto-char (point-min))
	(and (looking-at diff-hunk-header-re) (eq (char-after) ?*)))
      (let ((mod (buffer-modified-p)))
	(unwind-protect
	    (diff-context->unified (point-min) (point-max))
	  (restore-buffer-modified-p mod)))))
      (and (re-search-forward diff-hunk-header-re-unified nil t)
	   (equal (match-string 2) (match-string 4)))))

(defun diff-sanity-check-context-hunk-half (lines)
  (let ((count lines))
    (while
        (cond
         ((and (memq (char-after) '(?\s ?! ?+ ?-))
               (memq (char-after (1+ (point))) '(?\s ?\t)))
          (decf count) t)
         ((or (zerop count) (= count lines)) nil)
         ((memq (char-after) '(?! ?+ ?-))
          (if (not (and (eq (char-after (1+ (point))) ?\n)
                        (y-or-n-p "Try to auto-fix whitespace loss damage? ")))
              (error "End of hunk ambiguously marked")
            (forward-char 1) (insert " ") (forward-line -1) t))
         ((< lines 0)
          (error "End of hunk ambiguously marked"))
         ((not (y-or-n-p "Try to auto-fix whitespace loss and word-wrap damage? "))
          (error "Abort!"))
         ((eolp) (insert "  ") (forward-line -1) t)
         (t (insert " ") (delete-region (- (point) 2) (- (point) 1)) t))
      (forward-line))))

(defun diff-sanity-check-hunk ()
  (let (;; Every modification is protected by a y-or-n-p, so it's probably
        ;; OK to override a read-only setting.
        (inhibit-read-only t))
    (save-excursion
      (cond
       ((not (looking-at diff-hunk-header-re))
        (error "Not recognizable hunk header"))

       ;; A context diff.
       ((eq (char-after) ?*)
        (if (not (looking-at "\\*\\{15\\}\\(?: .*\\)?\n\\*\\*\\* \\([0-9]+\\)\\(?:,\\([0-9]+\\)\\)? \\*\\*\\*\\*"))
            (error "Unrecognized context diff first hunk header format")
          (forward-line 2)
          (diff-sanity-check-context-hunk-half
	   (if (match-end 2)
	       (1+ (- (string-to-number (match-string 2))
		      (string-to-number (match-string 1))))
	     1))
          (if (not (looking-at diff-context-mid-hunk-header-re))
              (error "Unrecognized context diff second hunk header format")
            (forward-line)
            (diff-sanity-check-context-hunk-half
	     (if (match-end 2)
		 (1+ (- (string-to-number (match-string 2))
			(string-to-number (match-string 1))))
	       1)))))

       ;; A unified diff.
       ((eq (char-after) ?@)
        (if (not (looking-at diff-hunk-header-re-unified))
            (error "Unrecognized unified diff hunk header format")
          (let ((before (string-to-number (or (match-string 2) "1")))
                (after (string-to-number (or (match-string 4) "1"))))
            (forward-line)
            (while
                (case (char-after)
                  (?\s (decf before) (decf after) t)
                  (?-
                   (if (and (looking-at diff-file-header-re)
                            (zerop before) (zerop after))
                       ;; No need to query: this is a case where two patches
                       ;; are concatenated and only counting the lines will
                       ;; give the right result.  Let's just add an empty
                       ;; line so that our code which doesn't count lines
                       ;; will not get confused.
                       (progn (save-excursion (insert "\n")) nil)
                     (decf before) t))
                  (?+ (decf after) t)
                  (t
                   (cond
                    ((and diff-valid-unified-empty-line
                          ;; Not just (eolp) so we don't infloop at eob.
                          (eq (char-after) ?\n)
                          (> before 0) (> after 0))
                     (decf before) (decf after) t)
                    ((and (zerop before) (zerop after)) nil)
                    ((or (< before 0) (< after 0))
                     (error (if (or (zerop before) (zerop after))
                                "End of hunk ambiguously marked"
                              "Hunk seriously messed up")))
                    ((not (y-or-n-p (concat "Try to auto-fix " (if (eolp) "whitespace loss" "word-wrap damage") "? ")))
                     (error "Abort!"))
                    ((eolp) (insert " ") (forward-line -1) t)
                    (t (insert " ")
                       (delete-region (- (point) 2) (- (point) 1)) t))))
              (forward-line)))))

       ;; A plain diff.
       (t
        ;; TODO.
        )))))

(defun diff-hunk-text (hunk destp char-offset)
  "Return the literal source text from HUNK as (TEXT . OFFSET).
If DESTP is nil, TEXT is the source, otherwise the destination text.
CHAR-OFFSET is a char-offset in HUNK, and OFFSET is the corresponding
char-offset in TEXT."
	     (re-search-forward diff-context-mid-hunk-header-re nil t)
  "Return the buffer position (BEG . END) of the nearest occurrence of TEXT.
		    (cons (match-beginning 0) (match-end 0))))
		    (cons (match-beginning 0) (match-end 0)))))
    ;; Choose the closest match.
	(if (> (- (car forw) orig) (- orig (car back))) back forw)
(defun diff-find-approx-text (text)
  "Return the buffer position (BEG . END) of the nearest occurrence of TEXT.
Whitespace differences are ignored."
  (let* ((orig (point))
	 (re (concat "^[ \t\n]*"
		     (mapconcat 'regexp-quote (split-string text) "[ \t\n]+")
		     "[ \t\n]*\n"))
	 (forw (and (re-search-forward re nil t)
		    (cons (match-beginning 0) (match-end 0))))
	 (back (and (goto-char (+ orig (length text)))
		    (re-search-backward re nil t)
		    (cons (match-beginning 0) (match-end 0)))))
    ;; Choose the closest match.
    (if (and forw back)
	(if (> (- (car forw) orig) (- orig (car back))) back forw)
      (or back forw))))
(defsubst diff-xor (a b) (if a (if (not b) a) b))

(defun diff-find-source-location (&optional other-file reverse noprompt)
  "Find out (BUF LINE-OFFSET POS SRC DST SWITCHED).
BUF is the buffer corresponding to the source file.
LINE-OFFSET is the offset between the expected and actual positions
  of the text of the hunk or nil if the text was not found.
POS is a pair (BEG . END) indicating the position of the text in the buffer.
SRC and DST are the two variants of text as returned by `diff-hunk-text'.
  SRC is the variant that was found in the buffer.
SWITCHED is non-nil if the patch is already applied.
NOPROMPT, if non-nil, means not to prompt the user."
	   (char-offset (- (point) (progn (diff-beginning-of-hunk 'try-harder)
                                          (point))))
           ;; Check that the hunk is well-formed.  Otherwise diff-mode and
           ;; the user may disagree on what constitutes the hunk
           ;; (e.g. because an empty line truncates the hunk mid-course),
           ;; leading to potentially nasty surprises for the user.
	   ;;
	   ;; Suppress check when NOPROMPT is non-nil (Bug#3033).
           (_ (unless noprompt (diff-sanity-check-hunk)))
	   (hunk (buffer-substring
                  (point) (save-excursion (diff-end-of-hunk) (point))))
		       (unless (re-search-forward
                                diff-context-mid-hunk-header-re nil t)
	   (file (or (diff-find-file-name other noprompt)
                     (error "Can't find the file")))
	       (switched nil)
	       ;; FIXME: Check for case where both OLD and NEW are found.
	       (pos (or (diff-find-text (car old))
			(progn (setq switched t) (diff-find-text (car new)))
			(progn (setq switched nil)
			       (condition-case nil
				   (diff-find-approx-text (car old))
				 (invalid-regexp nil)))	;Regex too big.
			(progn (setq switched t)
			       (condition-case nil
				   (diff-find-approx-text (car new))
				 (invalid-regexp nil)))	;Regex too big.
			(progn (setq switched nil) nil))))
	   (if pos
	       (list (count-lines orig-pos (car pos)) pos)
	     (list nil (cons orig-pos (+ orig-pos (length (car old))))))
(defvar diff-apply-hunk-to-backup-file nil)
      ;; Sometimes we'd like to have the following behavior: if REVERSE go
      ;; to the new file, otherwise go to the old.  But that means that by
      ;; default we use the old file, which is the opposite of the default
      ;; for diff-goto-source, and is thus confusing.  Also when you don't
      ;; know about it it's pretty surprising.
      ;; TODO: make it possible to ask explicitly for this behavior.
      ;;
      ;; This is duplicated in diff-test-hunk.
     ((with-current-buffer buf
        (and buffer-file-name
             (backup-file-name-p buffer-file-name)
             (not diff-apply-hunk-to-backup-file)
             (not (set (make-local-variable 'diff-apply-hunk-to-backup-file)
                       (yes-or-no-p (format "Really apply this hunk to %s? "
                                            (file-name-nondirectory
                                             buffer-file-name)))))))
      (error "%s"
	     (substitute-command-keys
              (format "Use %s\\[diff-apply-hunk] to apply it to the other file"
                      (if (not reverse) "\\[universal-argument] ")))))
		  (goto-char (+ (car pos) (cdr old)))
	(goto-char (car pos))
	(delete-region (car pos) (cdr pos))
      (set-window-point (display-buffer buf) (+ (car pos) (cdr new)))
    (set-window-point (display-buffer buf) (+ (car pos) (cdr src)))
(defalias 'diff-mouse-goto-source 'diff-goto-source)

(defun diff-goto-source (&optional other-file event)
then `diff-jump-to-old-file' is also set, for the next invocations."
  (interactive (list current-prefix-arg last-input-event))
  (if event (posn-set-point (event-end event)))
      (goto-char (+ (car pos) (cdr src)))
  ;; Kill change-log-default-name so it gets recomputed each time, since
  ;; each hunk may belong to another file which may belong to another
  ;; directory and hence have a different ChangeLog file.
  (kill-local-variable 'change-log-default-name)
  (save-excursion
    (when (looking-at diff-hunk-header-re)
      (forward-line 1)
      (re-search-forward "^[^ ]" nil t))
    (destructuring-bind (&optional buf line-offset pos src dst switched)
        ;; Use `noprompt' since this is used in which-func-mode and such.
	(ignore-errors                ;Signals errors in place of prompting.
          (diff-find-source-location nil nil 'noprompt))
      (when buf
        (beginning-of-line)
        (or (when (memq (char-after) '(?< ?-))
              ;; Cursor is pointing at removed text.  This could be a removed
              ;; function, in which case, going to the source buffer will
              ;; not help since the function is now removed.  Instead,
              ;; try to figure out the function name just from the
              ;; code-fragment.
              (let ((old (if switched dst src)))
                (with-temp-buffer
                  (insert (car old))
                  (funcall (buffer-local-value 'major-mode buf))
                  (goto-char (+ (point-min) (cdr old)))
                  (add-log-current-defun))))
            (with-current-buffer buf
              (goto-char (+ (car pos) (cdr src)))
              (add-log-current-defun)))))))

(defun diff-ignore-whitespace-hunk ()
  "Re-diff the current hunk, ignoring whitespace differences."
  (interactive)
  (let* ((char-offset (- (point) (progn (diff-beginning-of-hunk 'try-harder)
                                        (point))))
	 (opts (case (char-after) (?@ "-bu") (?* "-bc") (t "-b")))
	 (line-nb (and (or (looking-at "[^0-9]+\\([0-9]+\\)")
			   (error "Can't find line number"))
		       (string-to-number (match-string 1))))
	 (inhibit-read-only t)
	 (hunk (delete-and-extract-region
		(point) (save-excursion (diff-end-of-hunk) (point))))
	 (lead (make-string (1- line-nb) ?\n)) ;Line nums start at 1.
	 (file1 (make-temp-file "diff1"))
	 (file2 (make-temp-file "diff2"))
	 (coding-system-for-read buffer-file-coding-system)
	 old new)
    (unwind-protect
	(save-excursion
	  (setq old (diff-hunk-text hunk nil char-offset))
	  (setq new (diff-hunk-text hunk t char-offset))
	  (write-region (concat lead (car old)) nil file1 nil 'nomessage)
	  (write-region (concat lead (car new)) nil file2 nil 'nomessage)
	  (with-temp-buffer
	    (let ((status
		   (call-process diff-command nil t nil
				 opts file1 file2)))
	      (case status
		(0 nil)			;Nothing to reformat.
		(1 (goto-char (point-min))
		   ;; Remove the file-header.
		   (when (re-search-forward diff-hunk-header-re nil t)
		     (delete-region (point-min) (match-beginning 0))))
		(t (goto-char (point-max))
		   (unless (bolp) (insert "\n"))
		   (insert hunk)))
	      (setq hunk (buffer-string))
	      (unless (memq status '(0 1))
		(error "Diff returned: %s" status)))))
      ;; Whatever happens, put back some equivalent text: either the new
      ;; one or the original one in case some error happened.
      (insert hunk)
      (delete-file file1)
      (delete-file file2))))

;;; Fine change highlighting.

(defface diff-refine-change
  '((((class color) (min-colors 88) (background light))
     :background "grey85")
    (((class color) (min-colors 88) (background dark))
     :background "grey60")
    (((class color) (background light))
     :background "yellow")
    (((class color) (background dark))
     :background "green")
    (t :weight bold))
  "Face used for char-based changes shown by `diff-refine-hunk'."
  :group 'diff-mode)

(defun diff-refine-preproc ()
  (while (re-search-forward "^[+>]" nil t)
    ;; Remove spurious changes due to the fact that one side of the hunk is
    ;; marked with leading + or > and the other with leading - or <.
    ;; We used to replace all the prefix chars with " " but this only worked
    ;; when we did char-based refinement (or when using
    ;; smerge-refine-weight-hack) since otherwise, the `forward' motion done
    ;; in chopup do not necessarily do the same as the ones in highlight
    ;; since the "_" is not treated the same as " ".
    (replace-match (cdr (assq (char-before) '((?+ . "-") (?> . "<"))))))
  )

(defun diff-refine-hunk ()
  "Highlight changes of hunk at point at a finer granularity."
  (interactive)
  (eval-and-compile (require 'smerge-mode))
  (save-excursion
    (diff-beginning-of-hunk 'try-harder)
    (let* ((style (diff-hunk-style))    ;Skips the hunk header as well.
           (beg (point))
           (props '((diff-mode . fine) (face diff-refine-change)))
           (end (progn (diff-end-of-hunk) (point))))

      (remove-overlays beg end 'diff-mode 'fine)

      (goto-char beg)
      (case style
        (unified
         (while (re-search-forward "^\\(?:-.*\n\\)+\\(\\)\\(?:\\+.*\n\\)+"
                                   end t)
           (smerge-refine-subst (match-beginning 0) (match-end 1)
                                (match-end 1) (match-end 0)
                                props 'diff-refine-preproc)))
        (context
         (let* ((middle (save-excursion (re-search-forward "^---")))
                (other middle))
           (while (re-search-forward "^\\(?:!.*\n\\)+" middle t)
             (smerge-refine-subst (match-beginning 0) (match-end 0)
                                  (save-excursion
                                    (goto-char other)
                                    (re-search-forward "^\\(?:!.*\n\\)+" end)
                                    (setq other (match-end 0))
                                    (match-beginning 0))
                                  other
                                  props 'diff-refine-preproc))))
        (t ;; Normal diffs.
         (let ((beg1 (1+ (point))))
           (when (re-search-forward "^---.*\n" end t)
             ;; It's a combined add&remove, so there's something to do.
             (smerge-refine-subst beg1 (match-beginning 0)
                                  (match-end 0) end
                                  props 'diff-refine-preproc))))))))


(defun diff-add-change-log-entries-other-window ()
  "Iterate through the current diff and create ChangeLog entries.
I.e. like `add-change-log-entry-other-window' but applied to all hunks."
  (interactive)
  ;; XXX: Currently add-change-log-entry-other-window is only called
  ;; once per hunk.  Some hunks have multiple changes, it would be
  ;; good to call it for each change.
  (save-excursion
    (goto-char (point-min))
    (let ((orig-buffer (current-buffer)))
      (condition-case nil
	  ;; Call add-change-log-entry-other-window for each hunk in
	  ;; the diff buffer.
	  (while (progn
                   (diff-hunk-next)
                   ;; Move to where the changes are,
                   ;; `add-change-log-entry-other-window' works better in
                   ;; that case.
                   (re-search-forward
                    (concat "\n[!+-<>]"
                            ;; If the hunk is a context hunk with an empty first
                            ;; half, recognize the "--- NNN,MMM ----" line
                            "\\(-- [0-9]+\\(,[0-9]+\\)? ----\n"
                            ;; and skip to the next non-context line.
                            "\\( .*\n\\)*[+]\\)?")
                    nil t))
            (save-excursion
              (add-change-log-entry nil nil t nil t)))
        ;; When there's no more hunks, diff-hunk-next signals an error.
	(error nil)))))
;; arch-tag: 2571d7ff-bc28-4cf9-8585-42e21890be66