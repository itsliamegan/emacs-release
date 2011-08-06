;; Copyright (C) 1995, 1997, 1998, 2001, 2002, 2003, 2004,
;;   2005, 2006, 2007, 2008, 2009 Free Software Foundation, Inc.
;; Author: Morten Welinder <terra@gnu.org>
;; GNU Emacs is free software: you can redistribute it and/or modify
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.
;;			Arc	Lzh	Zip	Zoo	 Rar
;;			----------------------------------------
;; View listing		Intern	Intern	Intern	Intern   Y
;; Extract member	Y	Y	Y	Y        Y
;; Save changed member	Y	Y	Y	Y        N
;; Add new member	N	N	N	N        N
;; Delete member	Y	Y	Y	Y        N
;; Rename member	Y	Y	N	N        N
;; Chmod		-	Y	Y	-        N
;; Chown		-	Y	-	-        N
;; Chgrp		-	Y	-	-        N
;;             Headers come in three flavours called level 0, 1 and 2 headers.
;;             Level 2 header is free of DOS specific restrictions and most
;;             prevalently used.  Also level 1 and 2 headers consist of base
;;             and extension headers.  For more details see
;;             http://homepage1.nifty.com/dangan/en/Content/Program/Java/jLHA/Notes/Notes.html
;;             http://www.osirusoft.com/joejared/lzhformat.html
;;; Section: Configuration.
  ;; make-temp-name is safe here because we use this name
  ;; to create a directory.
  "Directory for temporary files made by `arc-mode.el'."
  "Regexp recognizing archive files names that are not local.
  "Hooks to run when an archive member has been extracted."
  "Program and its options to run in order to extract an arc file member.
  "Program and its options to run in order to delete arc file members.
  "Program and its options to run in order to update an arc file member.
  "Program and its options to run in order to extract an lzh file member.
  "Program and its options to run in order to delete lzh file members.
  "Program and its options to run in order to update an lzh file member.
  (if (and (not (executable-find "unzip"))
           (executable-find "pkunzip"))
      '("pkunzip" "-e" "-o-")
    '("unzip" "-qq" "-c"))
  "Program and its options to run in order to extract a zip file member.
be added."
;; For several reasons the latter behavior is not desirable in general.
  (if (and (not (executable-find "zip"))
           (executable-find "pkzip"))
      '("pkzip" "-d")
    '("zip" "-d" "-q"))
  "Program and its options to run in order to delete zip file members.
  (if (and (not (executable-find "zip"))
           (executable-find "pkzip"))
      '("pkzip" "-u" "-P")
    '("zip" "-q"))
  "Program and its options to run in order to update a zip file member.
  (if (and (not (executable-find "zip"))
           (executable-find "pkzip"))
      '("pkzip" "-u" "-P")
    '("zip" "-q" "-k"))
  "Program and its options to run in order to update a case fiddled zip member.
  "If non-nil then zip file members may be down-cased.
  "Program and its options to run in order to extract a zoo file member.
  "Program and its options to run in order to delete zoo file members.
  "Program and its options to run in order to update a zoo file member.
;;; Section: Variables

(defvar archive-subtype nil "Symbol describing archive type.")
(defvar archive-file-list-start nil "Position of first contents line.")
(defvar archive-file-list-end nil "Position just after last contents line.")
(defvar archive-proper-file-start nil "Position of real archive's start.")
(defvar archive-read-only nil "Non-nil if the archive is read-only on disk.")
(defvar archive-local-name nil "Name of local copy of remote archive.")
(defvar archive-mode-map
  (let ((map (make-keymap)))
    (suppress-keymap map)
    (define-key map " " 'archive-next-line)
    (define-key map "a" 'archive-alternate-display)
    ;;(define-key map "c" 'archive-copy)
    (define-key map "d" 'archive-flag-deleted)
    (define-key map "\C-d" 'archive-flag-deleted)
    (define-key map "e" 'archive-extract)
    (define-key map "f" 'archive-extract)
    (define-key map "\C-m" 'archive-extract)
    (define-key map "g" 'revert-buffer)
    (define-key map "h" 'describe-mode)
    (define-key map "m" 'archive-mark)
    (define-key map "n" 'archive-next-line)
    (define-key map "\C-n" 'archive-next-line)
    (define-key map [down] 'archive-next-line)
    (define-key map "o" 'archive-extract-other-window)
    (define-key map "p" 'archive-previous-line)
    (define-key map "q" 'quit-window)
    (define-key map "\C-p" 'archive-previous-line)
    (define-key map [up] 'archive-previous-line)
    (define-key map "r" 'archive-rename-entry)
    (define-key map "u" 'archive-unflag)
    (define-key map "\M-\C-?" 'archive-unmark-all-files)
    (define-key map "v" 'archive-view)
    (define-key map "x" 'archive-expunge)
    (define-key map "\177" 'archive-unflag-backwards)
    (define-key map "E" 'archive-extract-other-window)
    (define-key map "M" 'archive-chmod-entry)
    (define-key map "G" 'archive-chgrp-entry)
    (define-key map "O" 'archive-chown-entry)
    ;; Let mouse-1 follow the link.
    (define-key map [follow-link] 'mouse-face)

    (if (fboundp 'command-remapping)
        (progn
          (define-key map [remap advertised-undo] 'archive-undo)
          (define-key map [remap undo] 'archive-undo))
      (substitute-key-definition 'advertised-undo 'archive-undo map global-map)
      (substitute-key-definition 'undo 'archive-undo map global-map))

    (define-key map
      (if (featurep 'xemacs) 'button2 [mouse-2]) 'archive-extract)

    (if (featurep 'xemacs)
        ()				; out of luck

      (define-key map [menu-bar immediate]
        (cons "Immediate" (make-sparse-keymap "Immediate")))
      (define-key map [menu-bar immediate alternate]
        '(menu-item "Alternate Display" archive-alternate-display
          :enable (boundp (archive-name "alternate-display"))
          :help "Toggle alternate file info display"))
      (define-key map [menu-bar immediate view]
        '(menu-item "View This File" archive-view
          :help "Display file at cursor in View Mode"))
      (define-key map [menu-bar immediate display]
        '(menu-item "Display in Other Window" archive-display-other-window
          :help "Display file at cursor in another window"))
      (define-key map [menu-bar immediate find-file-other-window]
        '(menu-item "Find in Other Window" archive-extract-other-window
          :help "Edit file at cursor in another window"))
      (define-key map [menu-bar immediate find-file]
        '(menu-item "Find This File" archive-extract
          :help "Extract file at cursor and edit it"))

      (define-key map [menu-bar mark]
        (cons "Mark" (make-sparse-keymap "Mark")))
      (define-key map [menu-bar mark unmark-all]
        '(menu-item "Unmark All" archive-unmark-all-files
          :help "Unmark all marked files"))
      (define-key map [menu-bar mark deletion]
        '(menu-item "Flag" archive-flag-deleted
          :help "Flag file at cursor for deletion"))
      (define-key map [menu-bar mark unmark]
        '(menu-item "Unflag" archive-unflag
          :help "Unmark file at cursor"))
      (define-key map [menu-bar mark mark]
        '(menu-item "Mark" archive-mark
          :help "Mark file at cursor"))

      (define-key map [menu-bar operate]
        (cons "Operate" (make-sparse-keymap "Operate")))
      (define-key map [menu-bar operate chown]
        '(menu-item "Change Owner..." archive-chown-entry
          :enable (fboundp (archive-name "chown-entry"))
          :help "Change owner of marked files"))
      (define-key map [menu-bar operate chgrp]
        '(menu-item "Change Group..." archive-chgrp-entry
          :enable (fboundp (archive-name "chgrp-entry"))
          :help "Change group ownership of marked files"))
      (define-key map [menu-bar operate chmod]
        '(menu-item "Change Mode..." archive-chmod-entry
          :enable (fboundp (archive-name "chmod-entry"))
          :help "Change mode (permissions) of marked files"))
      (define-key map [menu-bar operate rename]
        '(menu-item "Rename to..." archive-rename-entry
          :enable (fboundp (archive-name "rename-entry"))
          :help "Rename marked files"))
      ;;(define-key map [menu-bar operate copy]
      ;;  '(menu-item "Copy to..." archive-copy))
      (define-key map [menu-bar operate expunge]
        '(menu-item "Expunge Marked Files" archive-expunge
          :help "Delete all flagged files from archive"))
      map))
  "Local keymap for archive mode listings.")
(defvar archive-file-name-indent nil "Column where file names start.")

(defvar archive-remote nil "Non-nil if the archive is outside file system.")
  "Non-nil when alternate information is shown.")
(defvar archive-superior-buffer nil "In archive members, points to archive.")
(defvar archive-subfile-mode nil "Non-nil in archive member buffers.")
(defvar archive-file-name-coding-system nil)
(make-variable-buffer-local 'archive-file-name-coding-system)
(put 'archive-file-name-coding-system 'permanent-local t)

;;; Section: Support functions.

(eval-when-compile
  (defsubst byte-after (pos)
    "Like char-after but an eight-bit char is converted to unibyte."
    (multibyte-char-to-unibyte (char-after pos)))
  (defsubst insert-unibyte (&rest args)
    "Like insert but don't make unibyte string and eight-bit char multibyte."
    (dolist (elt args)
      (if (integerp elt)
	  (insert (if (< elt 128) elt (decode-char 'eight-bit elt)))
	(insert (string-to-multibyte elt)))))
  )
(defun archive-l-e (str &optional len float)
  "Convert little endian string/vector STR to integer.
Alternatively, STR may be a buffer position in the current buffer
in which case a second argument, length LEN, should be supplied.
FLOAT, if non-nil, means generate and return a float instead of an integer
\(use this for numbers that can overflow the Emacs integer)."
  (setq str (string-as-unibyte str))
            result (+ (if float (* result 256.0) (ash result 8))
		      (aref str (- len i)))))
(defun archive-unixdate (low high)
  "Stringify Unix (LOW HIGH) date."
  (let ((str (current-time-string (cons high low))))
    (format "%s-%s-%s"
	    (substring str 8 10)
	    (substring str 4 7)
	    (substring str 20 24))))
(defun archive-unixtime (low high)
  "Stringify Unix (LOW HIGH) time."
  (let ((str (current-time-string (cons high low))))
    (substring str 11 19)))
Does not signal an error if optional argument NOERROR is non-nil."
;;; Section: the mode definition
	  (add-hook 'write-contents-functions 'archive-write-file nil t))
	(run-mode-hooks (archive-name "mode-hook") 'archive-mode-hook)
      (setq archive-file-name-coding-system
	    (or file-name-coding-system
		default-file-name-coding-system
		locale-coding-system))
      (if default-enable-multibyte-characters
	  (set-buffer-multibyte 'to))

(let ((item1 '(archive-subfile-mode " Archive")))
      (setq minor-mode-alist (cons item1 minor-mode-alist))))
          ;; This pattern modeled on the BSD/GNU+Linux `file' command.
          ;; Have seen capital "LHA's", and file has lower case "LHa's" too.
          ;; Note this regexp is also in archive-exe-p.
          ((looking-at "MZ\\(.\\|\n\\)\\{34\\}LH[aA]'s SFX ") 'lzh-exe)
          ((looking-at "Rar!") 'rar)
          ((looking-at "!<arch>\n") 'ar)
          ((and (looking-at "MZ")
                (re-search-forward "Rar!" (+ (point) 100000) t))
           'rar-exe)

(defun archive-desummarize ()
  (let ((inhibit-read-only t)
        (modified (buffer-modified-p)))
    (widen)
    (delete-region (point-min) archive-proper-file-start)
    (restore-buffer-modified-p modified)))


  (let ((inhibit-read-only t))
    (setq archive-proper-file-start (copy-marker (point-min) t))
    (set (make-local-variable 'change-major-mode-hook) 'archive-desummarize)
  (let ((no (archive-get-lineno)))
    (archive-desummarize)
     (lambda (fil)
       ;; Using `concat' here copies the text also, so we can add
       ;; properties without problems.
       (let ((text (concat (aref fil 0) "\n")))
         (if (featurep 'xemacs)
             ()                         ; out of luck
           (add-text-properties
            (aref fil 1) (aref fil 2)
            '(mouse-face highlight
              help-echo "mouse-2: extract this file into a buffer")
            text))
         text))
To avoid very long lines archive mode does not show all information.
;;; Section: Local archive copy handling
	  (if (if (fboundp 'msdos-long-file-names)
		  (not (msdos-long-file-names)))
	  ;; Maked sure all the leading directories in
	  ;; archive-local-name exist under archive-tmpdir, so that
	  ;; the directory structure recorded in the archive is
	  ;; reconstructed in the temporary directory.
	  (make-directory (file-name-directory archive-local-name) t)
	    (inhibit-read-only t))
;;; Section: Member extraction

(defun archive-try-jka-compr ()
  (when (and auto-compression-mode
             (jka-compr-get-compression-info buffer-file-name))
    (let* ((basename (file-name-nondirectory buffer-file-name))
           (tmpname (if (string-match ":\\([^:]+\\)\\'" basename)
                        (match-string 1 basename) basename))
           (tmpfile (make-temp-file (file-name-sans-extension tmpname)
                                    nil
                                    (file-name-extension tmpname 'period))))
      (unwind-protect
          (progn
            (let ((coding-system-for-write 'no-conversion)
                  ;; Don't re-compress this data just before decompressing it.
                  (jka-compr-inhibit t))
              (write-region (point-min) (point-max) tmpfile nil 'quiet))
            (erase-buffer)
            (let ((coding-system-for-read 'no-conversion))
              (insert-file-contents tmpfile)))
        (delete-file tmpfile)))))
    (let ((buffer-undo-list t)
	  (coding
	       ;; dos-w32.el defines the function
	       ;; find-buffer-file-type-coding-system for DOS/Windows
	       ;; systems which preserves the coding-system of existing files.
	       ;; (That function is called via file-coding-system-alist.)
	       ;; Here, we want it to act as if the extracted file existed.
	       ;; The following let-binding of file-name-handler-alist forces
	       ;; find-file-not-found-set-buffer-file-coding-system to ignore
	       ;; the file's name (see dos-w32.el).
		 (car (find-operation-coding-system
		       'insert-file-contents
		       (cons filename (current-buffer)) t))))))
      (unless (or coding-system-for-read
                  enable-multibyte-characters)
        (setq coding
              (coding-system-change-text-conversion coding 'raw-text)))
      (unless (memq coding '(nil no-conversion))
        (decode-coding-region (point-min) (point-max) coding)
      (after-insert-file-set-coding (- (point-max) (point-min))))))

(define-obsolete-function-alias 'archive-mouse-extract 'archive-extract "22.1")

(defun archive-extract (&optional other-window-p event)
  (interactive (list nil last-input-event))
  (if event (posn-set-point (event-end event)))
	 (arcfilename (expand-file-name (concat arcname ":" iname)))
         (just-created nil)
	 (file-name-coding archive-file-name-coding-system))
      (if (and buffer
	       (string= (buffer-file-name buffer) arcfilename))
	(setq bufname (generate-new-buffer-name bufname))
        (with-current-buffer buffer
          (setq buffer-file-name arcfilename)
          (add-hook 'write-file-functions 'archive-write-file-member nil t)
	  (setq archive-file-name-coding-system file-name-coding)
			    archive-file-name-coding-system))
            (archive-try-jka-compr)     ;Pretty ugly hack :-(
	    (when (derived-mode-p 'archive-mode)
              (setq archive-remote t)
              (if read-only-p (setq archive-read-only t))
              ;; We will write out the archive ourselves if it is
              ;; part of another archive.
              (remove-hook 'write-contents-functions 'archive-write-file t))
            (run-hooks 'archive-extract-hooks)
          (cond
           (view-p (view-buffer
		    buffer (and just-created 'kill-buffer-if-not-modified)))
           ((eq other-window-p 'display) (display-buffer buffer))
           (other-window-p (switch-to-buffer-other-window buffer))
           (t (switch-to-buffer buffer))))))
    (cond ((and (numberp exit-status) (zerop exit-status))
			 (while (and bufs
                                     (not (with-current-buffer (car bufs)
                                            (derived-mode-p 'archive-mode))))
                           (setq bufs (cdr bufs)))
  (with-current-buffer arcbuf
    (or (derived-mode-p 'archive-mode)
  (let ((func (with-current-buffer arcbuf
                (archive-name "add-new-member")))
	(with-current-buffer arcbuf
;;; Section: IO stuff
      (let ((writer  (with-current-buffer archive-superior-buffer
                       (archive-name "write-file-member")))
	    (archive (with-current-buffer archive-superior-buffer
                       (archive-maybe-copy (buffer-file-name)))))
	    (write-region nil nil tmpfile nil 'nomessage))
	  (setq ename
		(encode-coding-string ename archive-file-name-coding-system))
          (let* ((coding-system-for-write 'no-conversion)
		 (exitcode (apply 'call-process
				  (car command)
				  nil
				  nil
				  nil
				  (append (cdr command)
					  (list archive ename)))))
            (or (zerop exitcode)
		(error "Updating was unsuccessful (%S)" exitcode))))
;;; Section: Marking and unmarking.
        (inhibit-read-only t))
    (restore-buffer-modified-p modified))
  (archive-flag-deleted p ?\s))
  (archive-flag-deleted (- p) ?\s))
	(inhibit-read-only t))
        (or (= (following-char) ?\s)
            (progn (delete-char 1) (insert ?\s)))
    (restore-buffer-modified-p modified)))
;;; Section: Operate
as a relative change like \"g+rw\" as for chmod(2)."
  "Change the name associated with this entry in the archive file."
	  (funcall func
		   (encode-coding-string newname
					 archive-file-name-coding-system)
  (let ((inhibit-read-only t))
;;; Section: Arc Archives
		(= (byte-after p) ?\C-z)
		(> (byte-after (1+ p)) 0))
	     (efnname (decode-coding-string (substring namefld 0 fnlen)
					    archive-file-name-coding-system))
	     ;; Convert to float to avoid overflow for very large files.
             (csize   (archive-l-e (+ p 15) 4 'float))
             (ucsize  (archive-l-e (+ p 25) 4 'float))
             (text    (format "  %8.0f  %-11s  %-8s  %s"
	      ;; p needs to stay an integer, since we use it in char-after
	      ;; above.  Passing through `round' limits the compressed size
	      ;; to most-positive-fixnum, but if the compressed size exceeds
	      ;; that, we cannot visit the archive anyway.
              p (+ p 29 (round csize)))))
	      (format "  %8.0f                         %d file%s"
(defun archive-arc-rename-entry (newname descr)
      (error "File names in arc files must not contain a directory component"))
	(inhibit-read-only t))
	(insert-unibyte name)))))
;;; Section: Lzh Archives
(defun archive-lzh-summarize (&optional start)
  (let ((p (or start 1)) ;; 1 for .lzh, something further on for .exe
    (while (progn (goto-char p)		;beginning of a base header.
      (let* ((hsize   (byte-after p))	;size of the base header (level 0 and 1)
	     ;; Convert to float to avoid overflow for very large files.
	     (csize   (archive-l-e (+ p 7) 4 'float)) ;size of a compressed file to follow (level 0 and 2),
					;size of extended headers + the compressed file to follow (level 1).
             (ucsize  (archive-l-e (+ p 11) 4 'float))	;size of an uncompressed file.
	     (time1   (archive-l-e (+ p 15) 2))	;date/time (MSDOS format in level 0, 1 headers
	     (time2   (archive-l-e (+ p 17) 2))	;and UNIX format in level 2 header.)
	     (hdrlvl  (byte-after (+ p 20))) ;header level
	     thsize		;total header size (base + extensions)
	     fnlen efnname osid fiddle ifnname width p2
	     neh	;beginning of next extension header (level 1 and 2)
	     mode modestr uid gid text dir prname
	     gname uname modtime moddate)
	(if (= hdrlvl 3) (error "can't handle lzh level 3 header type"))
	(when (or (= hdrlvl 0) (= hdrlvl 1))
	  (setq fnlen   (byte-after (+ p 21))) ;filename length
	  (setq efnname (let ((str (buffer-substring (+ p 22) (+ p 22 fnlen))))	;filename from offset 22
			(decode-coding-string
			 str archive-file-name-coding-system)))
	  (setq p2      (+ p 22 fnlen))) ;
	(if (= hdrlvl 1)
            (setq neh (+ p2 3))         ;specific to level 1 header
	  (if (= hdrlvl 2)
              (setq neh (+ p 24))))     ;specific to level 2 header
	(if neh		;if level 1 or 2 we expect extension headers to follow
	    (let* ((ehsize (archive-l-e neh 2))	;size of the extension header
		   (etype (byte-after (+ neh 2)))) ;extension type
	      (while (not (= ehsize 0))
		 ((= etype 1)	;file name
		  (let ((i (+ neh 3)))
		    (while (< i (+ neh ehsize))
		      (setq efnname (concat efnname (char-to-string (byte-after i))))
		      (setq i (1+ i)))))
		 ((= etype 2)	;directory name
		  (let ((i (+ neh 3)))
		    (while (< i (+ neh ehsize))
				    (setq dir (concat dir
						       (if (= (byte-after i)
		 ((= etype 80)		;Unix file permission
		  (setq mode (archive-l-e (+ neh 3) 2)))
		 ((= etype 81)		;UNIX file group/user ID
		  (progn (setq uid (archive-l-e (+ neh 3) 2))
			 (setq gid (archive-l-e (+ neh 5) 2))))
		 ((= etype 82)		;UNIX file group name
		  (let ((i (+ neh 3)))
		    (while (< i (+ neh ehsize))
		      (setq gname (concat gname (char-to-string (char-after i))))
		      (setq i (1+ i)))))
		 ((= etype 83)		;UNIX file user name
		  (let ((i (+ neh 3)))
		    (while (< i (+ neh ehsize))
		      (setq uname (concat uname (char-to-string (char-after i))))
		      (setq i (1+ i)))))
		(setq neh (+ neh ehsize))
		(setq ehsize (archive-l-e neh 2))
		(setq etype (byte-after (+ neh 2))))
	      ;;get total header size for level 1 and 2 headers
	      (setq thsize (- neh p))))
	(if (= hdrlvl 0)  ;total header size
	    (setq thsize hsize))
        ;; OS ID field not present in level 0 header, use code 0 "generic"
        ;; in that case as per lha program header.c get_header()
	(setq osid (cond ((= hdrlvl 0)  0)
                         ((= hdrlvl 1)  (char-after (+ p 22 fnlen 2)))
                         ((= hdrlvl 2)  (char-after (+ p 23)))))
        ;; Filename fiddling must follow the lha program, otherwise the name
        ;; passed to "lha pq" etc won't match (which for an extract silently
        ;; results in no output).  As of version 1.14i it goes from the OS ID,
        ;; - For 'M' MSDOS: msdos_to_unix_filename() downcases always, and
        ;;   converts "\" to "/".
        ;; - For 0 generic: generic_to_unix_filename() downcases if there's
        ;;   no lower case already present, and converts "\" to "/".
        ;; - For 'm' MacOS: macos_to_unix_filename() changes "/" to ":" and
        ;;   ":" to "/"
	(setq fiddle (cond ((= ?M osid) t)
                           ((= 0 osid)  (string= efnname (upcase efnname)))))
	(setq ifnname (if fiddle (downcase efnname) efnname))
	(setq prname (if dir (concat dir ifnname) ifnname))
	(setq width (if prname (string-width prname) 0))
	(setq moddate (if (= hdrlvl 2)
			  (archive-unixdate time1 time2) ;level 2 header in UNIX format
			(archive-dosdate time2))) ;level 0 and 1 header in DOS format
	(setq modtime (if (= hdrlvl 2)
			  (archive-unixtime time1 time2)
			(archive-dostime time1)))
			  (format "  %8.0f  %5S  %5S  %s"
			(format "  %10s  %8.0f  %-11s  %-8s  %s"
				moddate
				modtime
				prname)))
				   (- (length text) (length prname))
                          files))
	(cond ((= hdrlvl 1)
	       ;; p needs to stay an integer, since we use it in goto-char
	       ;; above.  Passing through `round' limits the compressed size
	       ;; to most-positive-fixnum, but if the compressed size exceeds
	       ;; that, we cannot visit the archive anyway.
	       (setq p (+ p hsize 2 (round csize))))
	      ((or (= hdrlvl 2) (= hdrlvl 0))
	       (setq p (+ p thsize 2 (round csize)))))
	))
		       "  %8.0f                %d file%s"
		     "              %8.0f                         %d file%s")))
	    sum (+ sum (byte-after p))
(defun archive-lzh-rename-entry (newname descr)
	     (oldhsize (byte-after p))
	     (oldfnlen (byte-after (+ p 21)))
	     (inhibit-read-only t))
	(insert-unibyte newfnlen newname)
	(insert-unibyte newhsize (archive-lzh-resum p newhsize))))))
  (save-excursion
    (save-restriction
      (dolist (fil files)
	(let* ((p (+ archive-proper-file-start (aref fil 4)))
	       (hsize   (byte-after p))
	       (fnlen   (byte-after (+ p 21)))
	       (creator (if (>= (- hsize fnlen) 24) (byte-after (+ p2 2)) 0))
	       (inhibit-read-only t))
		(insert-unibyte (logand newval 255) (lsh newval -8))
		(insert-unibyte (archive-lzh-resum (1+ p) hsize)))
		     (aref fil 1) errtxt)))))))
   (lambda (old) (archive-calc-mode old newmode t))

;; -------------------------------------------------------------------------
;;; Section: Lzh Self-Extracting .exe Archives
;;
;; No support for modifying these files.  It looks like the lha for unix
;; program (as of version 1.14i) can't create or retain the DOS exe part.
;; If you do an "lha a" on a .exe for instance it renames and writes to a
;; plain .lzh.

(defun archive-lzh-exe-summarize ()
  "Summarize the contents of an LZH self-extracting exe, for `archive-mode'."

  ;; Skip the initial executable code part and apply archive-lzh-summarize
  ;; to the archive part proper.  The "-lh5-" etc regexp here for the start
  ;; is the same as in archive-find-type.
  ;;
  ;; The lha program (version 1.14i) does this in skip_msdos_sfx1_code() by
  ;; a similar scan.  It looks for "..-l..-" plus for level 0 or 1 a test of
  ;; the header checksum, or level 2 a test of the "attribute" and size.
  ;;
  (re-search-forward "..-l[hz][0-9ds]-" nil)
  (archive-lzh-summarize (match-beginning 0)))

;; `archive-lzh-extract' runs "lha pq", and that works for .exe as well as
;; .lzh files
(defalias 'archive-lzh-exe-extract 'archive-lzh-extract
  "Extract a member from an LZH self-extracting exe, for `archive-mode'.")

;;; Section: Zip Archives
  (let ((p (+ (point-min) (archive-l-e (+ (point) 16) 4)))
      (let* ((creator (byte-after (+ p 5)))
	     ;; (method  (archive-l-e (+ p 10) 2))
	     ;; Convert to float to avoid overflow for very large files.
             (ucsize  (archive-l-e (+ p 24) 4 'float))
			(decode-coding-string
			 str archive-file-name-coding-system)))
	     (mode    (cond ((memq creator '(2 3)) ; Unix
					  (logand 1 (byte-after (+ p 38))))
             (text    (format "  %10s  %8.0f  %-11s  %-8s  %s"
	      (format "              %8.0f                         %d file%s"
  (if (equal (car archive-zip-extract) "pkzip")
      (dolist (fil files)
	(let* ((p (+ archive-proper-file-start (car (aref fil 4))))
	       (creator (byte-after (+ p 5)))
	       (inhibit-read-only t))
	  (cond ((memq creator '(2 3)) ; Unix
		 (insert-unibyte (logand newval 255) (lsh newval -8)))
		 (insert-unibyte (logior (logand (byte-after (point)) 254)
					 (logand (logxor 1 (lsh newval -7)) 1)))
        ))))
;;; Section: Zoo Archives
	     ;; Convert to float to avoid overflow for very large files.
             (ucsize  (archive-l-e (+ p 20) 4 'float))
	     (dirtype (byte-after (+ p 4)))
	     (lfnlen  (if (= dirtype 2) (byte-after (+ p 56)) 0))
	     (ldirlen (if (= dirtype 2) (byte-after (+ p 57)) 0))
			(decode-coding-string
			 str archive-file-name-coding-system)))
             (text    (format "  %8.0f  %-11s  %-8s  %s"
	      (format "  %8.0f                         %d file%s"

;; -------------------------------------------------------------------------
;;; Section: Rar Archives

(defun archive-rar-summarize (&optional file)
  ;; File is used internally for `archive-rar-exe-summarize'.
  (unless file (setq file buffer-file-name))
  (let* ((copy (file-local-copy file))
         (maxname 10)
         (maxsize 5)
         (files ()))
    (with-temp-buffer
      (call-process "unrar-free" nil t nil "--list" (or file copy))
      (if copy (delete-file copy))
      (goto-char (point-min))
      (re-search-forward "^-+\n")
      (while (looking-at (concat " \\(.*\\)\n" ;Name.
                                 ;; Size ; Packed.
                                 " +\\([0-9]+\\) +[0-9]+"
                                 ;; Ratio ; Date'
                                 " +\\([0-9%]+\\) +\\([-0-9]+\\)"
                                 ;; Time ; Attr.
                                 " +\\([0-9:]+\\) +......"
                                 ;; CRC; Meth ; Var.
                                 " +[0-9A-F]+ +[^ \n]+ +[0-9.]+\n"))
        (goto-char (match-end 0))
        (let ((name (match-string 1))
              (size (match-string 2)))
          (if (> (length name) maxname) (setq maxname (length name)))
          (if (> (length size) maxsize) (setq maxsize (length size)))
          (push (vector name name nil nil
                        ;; Size, Ratio.
                        size (match-string 3)
                        ;; Date, Time.
                        (match-string 4) (match-string 5))
                files))))
    (setq files (nreverse files))
    (goto-char (point-min))
    (let* ((format (format " %%s %%s  %%%ds %%5s  %%s" maxsize))
           (sep (format format "--------" "-----" (make-string maxsize ?-)
                        "-----" ""))
           (column (length sep)))
      (insert (format format "  Date  " "Time " "Size " "Ratio" " Filename") "\n")
      (insert sep (make-string maxname ?-) "\n")
      (archive-summarize-files (mapcar (lambda (desc)
                                         (let ((text
                                                (format format
                                                         (aref desc 6)
                                                         (aref desc 7)
                                                         (aref desc 4)
                                                         (aref desc 5)
                                                         (aref desc 1))))
                                           (vector text
                                                   column
                                                   (length text))))
                                       files))
      (insert sep (make-string maxname ?-) "\n")
      (apply 'vector files))))

(defun archive-rar-extract (archive name)
  ;; unrar-free seems to have no way to extract to stdout or even to a file.
  (if (file-name-absolute-p name)
      ;; The code below assumes the name is relative and may do undesirable
      ;; things otherwise.
      (error "Can't extract files with non-relative names")
    (let ((dest (make-temp-file "arc-rar" 'dir)))
      (unwind-protect
          (progn
            (call-process "unrar-free" nil nil nil
                          "--extract" archive name dest)
            (insert-file-contents-literally (expand-file-name name dest)))
        (delete-file (expand-file-name name dest))
        (while (file-name-directory name)
          (setq name (directory-file-name (file-name-directory name)))
          (delete-directory (expand-file-name name dest)))
        (delete-directory dest)))))

;;; Section: Rar self-extracting .exe archives.

(defun archive-rar-exe-summarize ()
  (let ((tmpfile (make-temp-file "rarexe")))
    (unwind-protect
        (progn
          (goto-char (point-min))
          (re-search-forward "Rar!")
          (write-region (match-beginning 0) (point-max) tmpfile)
          (archive-rar-summarize tmpfile))
      (delete-file tmpfile))))

(defun archive-rar-exe-extract (archive name)
  (let* ((tmpfile (make-temp-file "rarexe"))
         (buf (find-buffer-visiting archive))
         (tmpbuf (unless buf (generate-new-buffer " *rar-exe*"))))
    (unwind-protect
        (progn
          (with-current-buffer (or buf tmpbuf)
            (save-excursion
              (save-restriction
                (if buf
                    ;; point-max unwidened is assumed to be the end of the
                    ;; summary text and the beginning of the actual file data.
                    (progn (goto-char (point-max)) (widen))
                  (insert-file-contents-literally archive)
                  (goto-char (point-min)))
                (re-search-forward "Rar!")
                (write-region (match-beginning 0) (point-max) tmpfile))))
          (archive-rar-extract tmpfile name))
      (if tmpbuf (kill-buffer tmpbuf))
      (delete-file tmpfile))))


;;; Section `ar' archives.

;; TODO: we currently only handle the basic format of ar archives,
;; not the GNU nor the BSD extensions.  As it turns out, this is sufficient
;; for .deb packages.

(autoload 'tar-grind-file-mode "tar-mode")

(defconst archive-ar-file-header-re
  "\\(.\\{16\\}\\)\\([ 0-9]\\{12\\}\\)\\([ 0-9]\\{6\\}\\)\\([ 0-9]\\{6\\}\\)\\([ 0-7]\\{8\\}\\)\\([ 0-9]\\{10\\}\\)`\n")

(defun archive-ar-summarize ()
  ;; File is used internally for `archive-rar-exe-summarize'.
  (let* ((maxname 10)
         (maxtime 16)
         (maxuser 5)
         (maxgroup 5)
         (maxmode 8)
         (maxsize 5)
         (files ()))
    (goto-char (point-min))
    (search-forward "!<arch>\n")
    (while (looking-at archive-ar-file-header-re)
      (let ((name (match-string 1))
            extname
            ;; Emacs will automatically use float here because those
            ;; timestamps don't fit in our ints.
            (time (string-to-number (match-string 2)))
            (user (match-string 3))
            (group (match-string 4))
            (mode (string-to-number (match-string 5) 8))
            (size (string-to-number (match-string 6))))
        ;; Move to the beginning of the data.
        (goto-char (match-end 0))
        (setq time
              (format-time-string
               "%Y-%m-%d %H:%M"
               (let ((high (truncate (/ time 65536))))
                 (list high (truncate (- time (* 65536.0 high)))))))
        (setq extname
              (cond ((equal name "//              ")
                     (propertize ".<ExtNamesTable>." 'face 'italic))
                    ((equal name "/               ")
                     (propertize ".<LookupTable>." 'face 'italic))
                    ((string-match "/? *\\'" name)
                     (substring name 0 (match-beginning 0)))))
        (setq user (substring user 0 (string-match " +\\'" user)))
        (setq group (substring group 0 (string-match " +\\'" group)))
        (setq mode (tar-grind-file-mode mode))
        ;; Move to the end of the data.
        (forward-char size) (if (eq ?\n (char-after)) (forward-char 1))
        (setq size (number-to-string size))
        (if (> (length name) maxname) (setq maxname (length name)))
        (if (> (length time) maxtime) (setq maxtime (length time)))
        (if (> (length user) maxuser) (setq maxuser (length user)))
        (if (> (length group) maxgroup) (setq maxgroup (length group)))
        (if (> (length mode) maxmode) (setq maxmode (length mode)))
        (if (> (length size) maxsize) (setq maxsize (length size)))
        (push (vector name extname nil mode
                      time user group size)
              files)))
    (setq files (nreverse files))
    (goto-char (point-min))
    (let* ((format (format "%%%ds %%%ds/%%-%ds  %%%ds %%%ds %%s"
                           maxmode maxuser maxgroup maxsize maxtime))
           (sep (format format (make-string maxmode ?-)
                         (make-string maxuser ?-)
                          (make-string maxgroup ?-)
                           (make-string maxsize ?-)
                           (make-string maxtime ?-) ""))
           (column (length sep)))
      (insert (format format "  Mode  " "User" "Group" " Size "
                      "      Date      " "Filename")
              "\n")
      (insert sep (make-string maxname ?-) "\n")
      (archive-summarize-files (mapcar (lambda (desc)
                                         (let ((text
                                                (format format
                                                         (aref desc 3)
                                                         (aref desc 5)
                                                         (aref desc 6)
                                                         (aref desc 7)
                                                         (aref desc 4)
                                                         (aref desc 1))))
                                           (vector text
                                                   column
                                                   (length text))))
                                       files))
      (insert sep (make-string maxname ?-) "\n")
      (apply 'vector files))))

(defun archive-ar-extract (archive name)
  (let ((destbuf (current-buffer))
        (archivebuf (find-file-noselect archive))
        (from nil) size)
    (with-current-buffer archivebuf
      (save-restriction
        ;; We may be in archive-mode or not, so either with or without
        ;; narrowing and with or without a prepended summary.
        (save-excursion
          (widen)
          (search-forward "!<arch>\n")
          (while (and (not from) (looking-at archive-ar-file-header-re))
            (let ((this (match-string 1)))
              (setq size (string-to-number (match-string 6)))
              (goto-char (match-end 0))
              (if (equal name this)
                  (setq from (point))
                ;; Move to the end of the data.
                (forward-char size) (if (eq ?\n (char-after)) (forward-char 1)))))
          (when from
            (set-buffer-multibyte nil)
            (with-current-buffer destbuf
              ;; Do it within the `widen'.
              (insert-buffer-substring archivebuf from (+ from size)))
            (set-buffer-multibyte 'to)
            ;; Inform the caller that the call succeeded.
            t))))))

;; arch-tag: e5966a01-35ec-4f27-8095-a043a79b457b