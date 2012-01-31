;; Copyright (C) 1998, 1999, 2000, 2001, 2002, 2003, 2004,2005, 2006,
;;   2007, 2008, 2009, 2010, 2011, 2012  Free Software Foundation, Inc.
(defvar diff-vc-backend nil
  "The VC backend that created the current Diff buffer, if any.")

    ("g" . revert-buffer)
(define-obsolete-face-alias 'diff-header-face 'diff-header "22.1")
(define-obsolete-face-alias 'diff-file-header-face 'diff-file-header "22.1")
(define-obsolete-face-alias 'diff-index-face 'diff-index "22.1")
(define-obsolete-face-alias 'diff-hunk-header-face 'diff-hunk-header "22.1")
(define-obsolete-face-alias 'diff-removed-face 'diff-removed "22.1")
(define-obsolete-face-alias 'diff-added-face 'diff-added "22.1")
(define-obsolete-face-alias 'diff-changed-face 'diff-changed "22.1")
(define-obsolete-face-alias 'diff-function-face 'diff-function "22.1")
(define-obsolete-face-alias 'diff-context-face 'diff-context "22.1")
(define-obsolete-face-alias 'diff-nonexistent-face 'diff-nonexistent "22.1")
         ;; Search the second match, since we're looking at the first.
	 (nexthunk (when (re-search-forward diff-hunk-header-re nil t 2)
		(if old2
		    (unless (string= new2 old2) (replace-match new2 t t nil 4))
		  (goto-char (match-end 3))
		  (insert "," new2))
		(if old1
		    (unless (string= new1 old1) (replace-match new1 t t nil 2))
		  (goto-char (match-end 1))
		  (insert "," new1))))
        (goto-char (point-min)) (forward-line (1- (string-to-number line)))
    (let* ((start (point))
           (style (diff-hunk-style))    ;Skips the hunk header as well.
           ;; Be careful to go back to `start' so diff-end-of-hunk gets
           ;; to read the hunk header's line info.
           (end (progn (goto-char start) (diff-end-of-hunk) (point))))
              ;; FIXME: this pops up windows of all the buffers.