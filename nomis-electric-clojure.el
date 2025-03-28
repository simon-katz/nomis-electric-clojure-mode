;;;; nomis-electric-clojure.el --- Minor mode for Electric Clojure ---  -*- lexical-binding: t -*-

;;;; This is an Emacs minor more for Electric Clojure.
;;;; Copyright (C) 2025 Simon Katz
;;;;
;;;; This program is free software: you can redistribute it and/or modify
;;;; it under the terms of the GNU General Public License as published by
;;;; the Free Software Foundation, either version 3 of the License, or
;;;; (at your option) any later version.
;;;;
;;;; This program is distributed in the hope that it will be useful,
;;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;; GNU General Public License for more details.
;;;;
;;;; You should have received a copy of the GNU General Public License
;;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;;; <one line to give the program's name and a brief idea of what it does.>
;;;; Copyright (C) <year>  <name of author>
;;;;
;;;; This program is free software: you can redistribute it and/or modify
;;;; it under the terms of the GNU General Public License as published by
;;;; the Free Software Foundation, either version 3 of the License, or
;;;; (at your option) any later version.
;;;;
;;;; This program is distributed in the hope that it will be useful,
;;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;;; GNU General Public License for more details.
;;;;
;;;; You should have received a copy of the GNU General Public License
;;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;;; ___________________________________________________________________________

;;;; Inspired by
;;;; https://gitlab.com/xificurC/hf-electric.el/-/blob/master/hf-electric.el
;;;; Permalink: https://gitlab.com/xificurC/hf-electric.el/-/blob/5e6e3d69e42a64869f1eecd8b804cf4b679f9501/hf-electric.el

;;;; avoid-case-bug-with-keywords
;;;; Note that we avoid `cl-case` and `cl-ecase` with keywords because of
;;;; a weird bug in some versions of Emacs.
;;;; See
;;;; https://github.com/clojure-emacs/cider/issues/2967#issuecomment-760714791

;;;; ___________________________________________________________________________

(require 'dash)
(require 'parseclj)

;;;; ___________________________________________________________________________
;;;; Customizable things

(defcustom nomis/ec-auto-enable? t
  "Whether to turn on `nomis-electric-clojure-mode` automatically by
looking for
  `[hyperfiddle.electric3` (for v3)
or, failing that, for
  `[hyperfiddle.electric` (for v2)
at the beginning of all .cljc buffers."
  :type 'boolean)

(defcustom nomis/ec-bound-for-electric-require-search 10000
  "How far to search in Electric Clojure source code buffers when
trying to detect the version of Electric Clojure.

You can re-run the auto-detection in any of the following ways:
- by running `M-x nomis/ec-redetect-electric-version`
- by turning `nomis-electric-clojure-mode` off and then back on
- by reverting the buffer."
  :type 'integer)

(defcustom nomis/ec-show-grammar-tooltips? nil
  "Whether to show grammar-related information in tooltips. This might blat
tooltips provided by other modes."
  :type 'boolean)

(defcustom nomis/ec-color-initial-whitespace? nil
  "Whether to color whitespace at the beginning of lines in
sited code."
  :type 'boolean)

(defcustom nomis/ec-use-underline? nil
  "Whether to use underline instead of background color for
Electric Clojure client and server code."
  :type 'boolean)

(defface nomis/ec-client-face/using-background
  `((((background dark)) ,(list :background "DarkGreen"))
    (t ,(list :background "DarkSeaGreen1")))
  "Face for Electric Clojure client code when using background color.")

(defface nomis/ec-server-face/using-background
  `((((background dark)) ,(list :background "IndianRed4"))
    (t ,(list :background "#ffc5c5")))
  "Face for Electric Clojure server code when using background color.")

(defface nomis/ec-unparsable-face/using-background
  `((t ,(list :box (list :color "Red"
                         :line-width '(-1 . -1)))))
  "Face for unparsable Electric Clojure code when using background color.
This includes both bad syntax and parts of Clojure that we don't know about.")

(defface nomis/ec-client-face/using-underline
  `((((background dark)) ,(list :underline (list :color "Chartreuse"
                                                 :style 'wave)))
    (t ,(list :underline (list :color "LimeGreen"
                               :style 'wave))))
  "Face for Electric Clojure client code when using underline.")

(defface nomis/ec-server-face/using-underline
  `((((background dark)) ,(list :underline (list :color "DeepPink1"
                                                 :style 'wave)))
    (t ,(list :underline (list :color "DeepPink1"
                               :style 'wave))))
  "Face for Electric Clojure server code when using underline.")

(defface nomis/ec-unparsable-face/using-underline
  `((t ,(list :box (list :color "Red"
                         :line-width '(-1 . -1)))))
  "Face for unparsable Electric Clojure code when using underline.
This includes both bad syntax and parts of Clojure that we don't know about.")

;;;; ___________________________________________________________________________
;;;; Faces not intended to be customized

(defvar -nomis/ec-show-debug-overlays? nil)

(defface -nomis/ec-neutral-face/normal
  `((t ,(list :background (face-background 'default) ; set by `nomis/ec-update-normal-neutral-face`, for use in case the default background changes
              :underline nil)))
  "Face for Electric code that is neither specifically client code nor
specifically server code, when `-nomis/ec-show-debug-overlays?` is nil."
  ;; This can be:
  ;; - code that is either client or server code; for example:
  ;;   - code that is not lexically within `e/client` or `e/server`
  ;;   - an `(e/fn ...)`
  ;; - code that is neither client nor server; for example:
  ;;   - in Electric v3:
  ;;     - symbols that are being bound; /eg/ the LHS of `let` bindings.
  )

(defface -nomis/ec-neutral-face/debug
  `((((background dark)) ,(list :background "Blue3"
                                :underline nil))
    (t ,(list :background "CadetBlue1"
              :underline nil)))
  "Face for Electric code that is neither specifically client code nor
specifically server code, when `-nomis/ec-show-debug-overlays?` is true.")

(defun nomis/ec-update-normal-neutral-face ()
  (set-face-attribute '-nomis/ec-neutral-face/normal
                      nil
                      :background
                      (face-background 'default)))

;;;; ___________________________________________________________________________

(define-error '-nomis/ec-parse-error "nomis-electric-clojure-mode: Cannot parse")

;;;; ___________________________________________________________________________

(defun -nomis/ec-compute-client-face ()
  (if nomis/ec-use-underline?
      'nomis/ec-client-face/using-underline
    'nomis/ec-client-face/using-background))

(defun -nomis/ec-compute-server-face ()
  (if nomis/ec-use-underline?
      'nomis/ec-server-face/using-underline
    'nomis/ec-server-face/using-background))

(defun -nomis/ec-compute-neutral-face ()
  (if -nomis/ec-show-debug-overlays?
      '-nomis/ec-neutral-face/debug
    '-nomis/ec-neutral-face/normal))

(defun -nomis/ec-compute-unparsable-face ()
  (if nomis/ec-use-underline?
      'nomis/ec-unparsable-face/using-underline
    'nomis/ec-unparsable-face/using-background))

(defface -nomis/ec-client-face
  `((t ,(list :inherit (-nomis/ec-compute-client-face)))) ; set by `-nomis/ec-update-faces`
  "Face for Electric Clojure client code.")

(defface -nomis/ec-server-face
  `((t ,(list :inherit (-nomis/ec-compute-server-face)))) ; set by `-nomis/ec-update-faces`
  "Face for Electric Clojure server code.")

(defface -nomis/ec-neutral-face
  `((t ,(list :inherit (-nomis/ec-compute-neutral-face)))) ; set by `-nomis/ec-update-faces`
  "Face for neutral Electric Clojure code.")

(defface -nomis/ec-unparsable-face
  `((t ,(list :inherit (-nomis/ec-compute-unparsable-face)))) ; set by `-nomis/ec-update-faces`
  "Face for unparsable Electric Clojure code.")

(defface -nomis/ec-place-for-metadata-face
  `((t ,(list :foreground "Yellow"
              :background "Red")))
  "Face for places that can have metadata.")

(defun -nomis/ec-update-faces ()
  (nomis/ec-update-normal-neutral-face)
  (set-face-attribute '-nomis/ec-client-face
                      nil
                      :inherit
                      (-nomis/ec-compute-client-face))
  (set-face-attribute '-nomis/ec-server-face
                      nil
                      :inherit
                      (-nomis/ec-compute-server-face))
  (set-face-attribute '-nomis/ec-neutral-face
                      nil
                      :inherit
                      (-nomis/ec-compute-neutral-face))
  (set-face-attribute '-nomis/ec-unparsable-face
                      nil
                      :inherit
                      (-nomis/ec-compute-unparsable-face)))

;;;; ___________________________________________________________________________

(defvar -nomis/ec-electric-version)
(make-variable-buffer-local '-nomis/ec-electric-version)

;;;; ___________________________________________________________________________

(defun -nomis/ec-message-no-disp (format-string &rest args)
  (let* ((inhibit-message t))
    (apply #'message format-string args)))

(defun -nomis/ec-pad-string (s n &optional pad-at-start?)
  (let* ((len (length s)))
    (if (>= len n)
        s
      (let* ((padding (make-string (max 0 (- n len))
                                   ?\s)))
        (if pad-at-start?
            (concat padding s)
          (concat s padding))))))

(defun -nomis/ec-pad-or-truncate-string (s n)
  (let* ((len (length s)))
    (cond ((= len n) s)
          ((< len n) (concat s
                             (make-string (max 0 (- n len))
                                          ?\s)))
          (t (substring s 0 n)))))

(defun -nomis/ec-line-number-string (&optional position absolute)
  (-nomis/ec-pad-string (number-to-string (line-number-at-pos position
                                                              absolute))
                        5
                        t))

(defun -nomis/ec-a-few-current-chars ()
  (let* ((start (point))
         (end-of-form (save-excursion
                        (when (-nomis/ec-can-forward-sexp?)
                          (forward-sexp))
                        (point)))
         (end-of-line (pos-eol)))
    (concat (buffer-substring start end-of-line)
            (when (< end-of-line end-of-form) "▶▶▶"))))

(defvar -nomis/ec-print-debug-info-to-messages-buffer? nil)

(defun -nomis/ec-debug (site what &optional force? print-env?)
  (when (or force? -nomis/ec-print-debug-info-to-messages-buffer?)
    (let* ((inhibit-message t))
      (-nomis/ec-message-no-disp "%s %s ---- %s %s => %s%s"
                                 (-nomis/ec-line-number-string)
                                 (make-string (* 2 *-nomis/ec-level*) ?\s)
                                 site
                                 (let* ((s (with-output-to-string (princ what))))
                                   (-nomis/ec-pad-string s 32))
                                 (-nomis/ec-a-few-current-chars)
                                 (if print-env?
                                     (format " ---- env = %s" *-nomis/ec-bound-vars*)
                                   "")))))

;;;; ___________________________________________________________________________
;;;; Some utilities copied from `nomis-sexp-utils` and other places. (I don't
;;;; want to make this package dependent on those.)

(defun -nomis/ec-plist-add (plist property value)
  "Add PROPERTY / VALUE to the front of PLIST. Does not check whether
PROPERTY is already in PLIST."
  (cons property (cons value plist)))

(defun -nomis/ec-plist-remove (plist property)
  "Delete PROPERTY from PLIST."
  (let ((p '()))
    (while plist
      (unless (eq property (car plist))
        (setq p (plist-put p (cl-first plist) (cl-second plist))))
      (setq plist (cddr plist)))
    p))

(defvar -nomis/ec-regexp-for-start-of-form-to-descend
  ;; Copied from `-nomis/sexp-regexp-for-bracketed-sexp-start`. This doesn't
  ;; include reader syntax for anonymous functions (/ie/ `#(...)`), which is
  ;; probably an oversite in the copied-from place. But that's handy for us
  ;; because these anonymous functions are hosted and they end up as
  ;; `sited-single-item`s.
  "(\\|\\[\\|{\\|#{")

(defun -nomis/ec-looking-at-start-of-form-to-descend? ()
  (looking-at -nomis/ec-regexp-for-start-of-form-to-descend))

(defun -nomis/ec-at-top-level? ()
  (save-excursion
    (condition-case nil
        (progn (backward-up-list) nil)
      (error t))))

(defun -nomis/ec-forward-sexp-gives-no-error? ()
  (save-excursion
    (condition-case nil
        (progn (forward-sexp) t)
      (error nil))))

(defun -nomis/ec-can-forward-sexp? ()
  ;; This is complicated, because `forward-sexp` behaves differently at end
  ;; of file and inside-and-at-end-of a `(...)` form.
  (cond ((not (-nomis/ec-at-top-level?))
         (-nomis/ec-forward-sexp-gives-no-error?))
        ((and (thing-at-point 'symbol)
              (save-excursion (ignore-errors (forward-char) t))
              (save-excursion (forward-char) (thing-at-point 'symbol)))
         ;; We're on a top-level symbol (and not after its end).
         t)
        (t
         (or (bobp) ; should really check that there's an sexp ahead
             (condition-case nil
                 (not (= (save-excursion
                           (backward-sexp)
                           (point))
                         (save-excursion
                           (forward-sexp)
                           (backward-sexp)
                           (point))))
               (error nil))))))

(defun nomis/ec-at-or-before-start-of-form-to-descend? ()
  ;; I can't get this to work with a regexp for whitespace followed by
  ;; a start-of-form-to-descend. So:
  (and (-nomis/ec-can-forward-sexp?)
       (save-excursion
         (forward-sexp)
         (backward-sexp)
         (-nomis/ec-looking-at-start-of-form-to-descend?))))

;;;; ___________________________________________________________________________
;;;; Flashing of the re-overlayed region, to help with debugging.

(defvar -nomis/ec-give-debug-feedback-flash? nil) ; for debugging

(defface -nomis/ec-flash-update-region-face-1
  `((t ,(list :background "red3")))
  "Face for Electric Clojure flashing of provided region.")

(defface -nomis/ec-flash-update-region-face-2
  `((t ,(list :background "yellow")))
  "Face for Electric Clojure flashing of extended region.")

(defun -nomis/ec-feedback-flash (start end start-2 end-2)
  (when -nomis/ec-give-debug-feedback-flash?
    (let* ((flash-overlay-1
            (let* ((ov (make-overlay start end nil t nil)))
              (overlay-put ov 'category 'nomis/ec-overlay)
              (overlay-put ov 'face '-nomis/ec-flash-update-region-face-1)
              (overlay-put ov 'evaporate t)
              (overlay-put ov 'priority 999999)
              ov))
           (flash-overlay-2
            (let* ((ov (make-overlay start-2 end-2 nil t nil)))
              (overlay-put ov 'category 'nomis/ec-overlay)
              (overlay-put ov 'face '-nomis/ec-flash-update-region-face-2)
              (overlay-put ov 'evaporate t)
              (overlay-put ov 'priority 999999)
              ov)))
      (run-at-time 0.2
                   nil
                   (lambda ()
                     (delete-overlay flash-overlay-1)
                     (delete-overlay flash-overlay-2))))))

;;;; ___________________________________________________________________________

(defvar *-nomis/ec-n-lumps-in-current-update* 0)

(defvar *-nomis/ec-site* 'nec/neutral
  "The site of the code currently being analysed. One of `nec/neutral`,
`nec/client` or `nec/server`.")

(defvar *-nomis/ec-site-electric-locals?* nil)

(defvar *-nomis/ec-default-site* nil)

(defvar *-nomis/ec-bound-vars* '())

(defvar *-nomis/ec-level* 0)

;;;; ___________________________________________________________________________
;;;; Overlay basics

(defun -nomis/ec-make-overlay (tag nesting-level face start end description)
  ;; (-nomis/ec-debug *-nomis/ec-site* 'make-overlay)
  (let* ((ov (make-overlay start end nil t nil)))
    (overlay-put ov 'nomis/tag (reverse tag))
    (overlay-put ov 'category 'nomis/ec-overlay)
    (overlay-put ov 'face face)
    (overlay-put ov 'evaporate t)
    (when (or description -nomis/ec-show-debug-overlays?)
      (let* ((messages (list description
                             (when -nomis/ec-show-debug-overlays?
                               (format "DEBUG: Tag = %s"
                                       (reverse tag)))
                             (when -nomis/ec-show-debug-overlays?
                               (format "DEBUG: Default site = %s"
                                       *-nomis/ec-default-site*)))))
        (overlay-put ov 'help-echo (-> (-remove #'null messages)
                                       (string-join "\n")))))
    (unless nomis/ec-color-initial-whitespace?
      ;; We have multiple overlays in the same place, so we need to
      ;; specify their priority.
      (overlay-put ov 'priority (cons nil nesting-level)))
    ov))

(defun -nomis/ec-overlay-lump (tag site nesting-level start end description)
  (-nomis/ec-debug site 'overlay-lump)
  (if (= start end)
      (-nomis/ec-debug site 'empty-lump)
    (cl-incf *-nomis/ec-n-lumps-in-current-update*)
    (let* ((face (cond ; See avoid-case-bug-with-keywords at top of file.
                  ((eq site 'nec/client)     '-nomis/ec-client-face)
                  ((eq site 'nec/server)     '-nomis/ec-server-face)
                  ((eq site 'nec/neutral)    '-nomis/ec-neutral-face)
                  ((eq site 'nec/unparsable) '-nomis/ec-unparsable-face)
                  ((eq site 'nec/place-for-metadata) '-nomis/ec-place-for-metadata-face)
                  (t (error "Bad case: site: %s" site)))))
      (cl-flet ((overlay (s e)
                  (-nomis/ec-make-overlay tag nesting-level face s e description)))
        (if nomis/ec-color-initial-whitespace?
            (let* ((start
                    ;; When a form has only whitespace between its start and the
                    ;; beginning of the line, color from the start of the line.
                    (if (and (not (bolp))
                             (= (point)
                                (save-excursion
                                  (beginning-of-line)
                                  (forward-whitespace 1))))
                        (save-excursion
                          (beginning-of-line)
                          (point))
                      start)))
              (overlay start end))
          (save-excursion
            (while (< (point) end)
              (let* ((start-2 (point))
                     (end-2 (min end
                                 (progn (end-of-line) (point)))))
                (unless (= start-2 end-2) ; don't create overlays of zero length
                  (overlay start-2 end-2))
                (unless (eobp) (forward-char))
                (when (bolp)
                  (back-to-indentation))))))))))

(defun -nomis/ec->grammar-description (x)
  (when nomis/ec-show-grammar-tooltips?
    (format "[Level=%s] %s"
            *-nomis/ec-level*
            (if (keywordp x)
                (-> x
                    symbol-name
                    (substring 1))
              x))))

;;;; ___________________________________________________________________________
;;;; ---- Parse and overlay helpers ----

(defun nomis/ec-down-list (desc)
  "If we are at or before the start of a bracketed s-expression, move
into that expression -- /ie/ move down one level of parentheses.
Otherwise throw an exception."
  (cond ((not (-nomis/ec-can-forward-sexp?))
         (let* ((msg (format "Missing %s" (first desc))))
           (signal '-nomis/ec-parse-error
                   (list msg (save-excursion
                               (backward-up-list)
                               (point))))))
        ((not (nomis/ec-at-or-before-start-of-form-to-descend?))
         (let* ((msg (format "A bracketed s-expression is needed for %s"
                             (first desc))))
           (signal '-nomis/ec-parse-error
                   (list msg (point)))))
        (t
         (down-list))))

(defun -nomis/ec-check-movement-possible (desc
                                          move-fn
                                          error-position-fn)
  (save-excursion
    (let* ((start (point)))
      (condition-case _
          (funcall move-fn)
        (error
         (let* ((msg (format "%s is missing or has an incorrect form"
                             (first desc))))
           (-nomis/ec-message-no-disp "%s" msg)
           (signal '-nomis/ec-parse-error
                   (list msg (progn (goto-char start)
                                    (funcall error-position-fn)
                                    (point))))))))))

(defun -nomis/ec-bof ()
  (forward-sexp)
  (backward-sexp))

(defun -nomis/ec-with-site* (tag site end description print-env? f)
  (cl-assert tag)
  (-nomis/ec-debug site tag nil print-env?)
  (let* ((*-nomis/ec-level* (1+ *-nomis/ec-level*)))
    (if (or (null site)
            (and (eq site *-nomis/ec-site*)
                 (not nomis/ec-show-grammar-tooltips?)))
        ;; No need for a new overlay.
        (funcall f)
      (let* ((*-nomis/ec-site* site)
             (start (point))
             (end (or end
                      (save-excursion (when (-nomis/ec-can-forward-sexp?)
                                        (forward-sexp))
                                      (point)))))
        (-nomis/ec-overlay-lump tag site *-nomis/ec-level* start end description)
        (funcall f)))))

(cl-defmacro -nomis/ec-with-site ((&key tag site end description print-env?)
                                  &body body)
  (declare (indent 1))
  `(-nomis/ec-with-site* ,tag ,site ,end ,description ,print-env?
                         (lambda () ,@body)))

(defun -nomis/ec-transmogrify-site (site inherited-site)
  (if (eq site 'nec/inherit)
      inherited-site
    site))

;;;; ___________________________________________________________________________
;;;; ---- Electric v2 ----

(defun -nomis/ec-overlay-args-of-form-v2 ()
  (-nomis/ec-debug *-nomis/ec-site* 'args-of-form)
  (save-excursion
    (nomis/ec-down-list 'args-of-form)
    (forward-sexp)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-debug *-nomis/ec-site* (list 'args-of-form 'arg))
      (-nomis/ec-walk-and-overlay-v2)
      (forward-sexp))))

(defun -nomis/ec-overlay-site-v2 (site)
  (save-excursion
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag '(site)
                          :site site
                          :description (-> site
                                           -nomis/ec->grammar-description))
      (-nomis/ec-overlay-args-of-form-v2))))

(defun -nomis/ec-overlay-other-bracketed-form-v2 ()
  (-nomis/ec-debug *-nomis/ec-site* 'other-bracketed-form)
  (save-excursion
    (nomis/ec-down-list 'other-bracketed-form)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-walk-and-overlay-v2)
      (forward-sexp))))

(defun -nomis/ec-walk-and-overlay-v2 ()
  (save-excursion
    (cond
     ((looking-at (-nomis/ec-operator-call-regexp "e/client"))
      (-nomis/ec-overlay-site-v2 'nec/client))
     ((looking-at (-nomis/ec-operator-call-regexp "e/server"))
      (-nomis/ec-overlay-site-v2 'nec/server))
     ((-nomis/ec-looking-at-start-of-form-to-descend?)
      (-nomis/ec-overlay-other-bracketed-form-v2)))))

;;;; ___________________________________________________________________________
;;;; ---- More parse and overlay helpers ----

(defvar -nomis/ec-debug-show-places-for-metadata? nil)

(defun -nomis/ec-show-place-for-metadata ()
  (when -nomis/ec-debug-show-places-for-metadata?
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag (list 'metadata-plop)
                          :site 'nec/place-for-metadata
                          :description "Place for metadata"
                          :end (1+ (point)))
      ;; Nothing more.
      )))

(defun -nomis/ec-skip-metadata ()
  (while (looking-at (regexp-quote "^"))
    (progn (forward-char)
           (forward-sexp))
    (when (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)))
  (-nomis/ec-show-place-for-metadata))

(defun -nomis/ec-overlay-unparsable (pos tag description)
  (save-excursion
    (goto-char pos)
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag (list 'unparsable tag)
                          :site 'nec/unparsable
                          :description description)
      ;; Nothing more.
      )))

(defun -nomis/ec-binding-structure->vars ()
  (cl-labels
      ((get-prop (ast prop)
         (cdr (assoc prop ast)))
       (get-type (ast) (get-prop ast :node-type))
       (get-position (ast) (1- ; we'll be zero-based
                            (get-prop ast :position)))
       (get-childen (ast) (get-prop ast :children))
       (get-form (ast) (get-prop ast :form))
       (get-value (ast) (get-prop ast :value))
       (ast->vars (ast)
         (let* ((sofar '())
                (unhandled-things '()))
           (cl-labels
               ((note-unhandled-thing (msg pos)
                  (push (list msg pos) unhandled-things))
                (name-after-any-slash (name)
                  (let* ((slash-pos (cl-search "/" name)))
                    (if slash-pos
                        (substring name (1+ slash-pos))
                      name)))
                (helper (ast)
                  (cond ((eq (get-type ast) :symbol)
                         (let* ((name (get-form ast)))
                           (push (name-after-any-slash name)
                                 sofar)))
                        ((eq (get-type ast) :keyword)
                         ;; This isn't allowed in all contexts, but we won't
                         ;; worry about that.
                         (let* ((name (substring (symbol-name (get-value ast))
                                                 1)))
                           (push (name-after-any-slash name)
                                 sofar)))
                        ((member (get-type ast) '(:root
                                                  :vector))
                         (cl-loop for x in (get-childen ast)
                                  do (unless (member (get-value x)
                                                     '(:as &))
                                       (helper x))))
                        ((eq (get-type ast) :map)
                         (cl-loop
                          for (k v) on (get-childen ast) by #'cddr
                          do (let ((kk (get-value k)))
                               (cond
                                ((eq kk :keys)
                                 (mapc #'helper (get-childen v)))
                                ((cl-search "/" (get-form k))
                                 (cl-loop for x in (get-childen v)
                                          do (helper x)))
                                ((eq kk :as)
                                 (helper v))
                                (t
                                 (helper k))))))
                        (t
                         (let* ((msg (format "Unhandled binding, of type %s"
                                             (get-type ast))))
                           (-nomis/ec-message-no-disp "%s" msg)
                           (note-unhandled-thing msg
                                                 (+ (point)
                                                    (get-position ast))))))))
             (helper ast))
           (cl-loop for (msg pos) in unhandled-things
                    do (-nomis/ec-overlay-unparsable pos
                                                     'bindings
                                                     msg))
           ;; For debugging:
           ;; (-nomis/ec-message-no-disp "sofar = %s"
           ;;                            (cl-format nil "~s" sofar))
           sofar)))
    (let* ((ast (parseclj-parse-clojure (thing-at-point 'sexp t))))
      (ast->vars ast))))

;;;; ___________________________________________________________________________
;;;; ---- -nomis/ec-overlay-term ----

(cl-defgeneric -nomis/ec-overlay-term (term-name tag inherited-site
                                                 &key))

(cl-defmethod -nomis/ec-overlay-term :before ((term-name t)
                                              tag
                                              inherited-site
                                              &key
                                              &allow-other-keys)
  (-nomis/ec-skip-metadata))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'operator))
                                      tag
                                      inherited-site
                                      &key
                                      &allow-other-keys)
  (-nomis/ec-check-movement-possible tag
                                     #'forward-sexp
                                     #'backward-up-list)
  ;; Operators that are symbols are colored the same as their parent form unless
  ;; the `operator` term has a `site` (as in, for example, `:dom/xxxx`) -- and
  ;; that coloring is handled in the generic term coloring.
  (unless (thing-at-point 'symbol)
    (-nomis/ec-walk-and-overlay-v3))
  (forward-sexp))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'name))
                                      tag
                                      inherited-site
                                      &key
                                      &allow-other-keys)
  (-nomis/ec-check-movement-possible (cons 'name tag)
                                     #'forward-sexp
                                     #'backward-up-list)
  (forward-sexp))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'name?))
                                      tag
                                      inherited-site
                                      &key
                                      &allow-other-keys)
  (when (thing-at-point 'symbol)
    (forward-sexp)))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'doc-string?))
                                      tag
                                      inherited-site
                                      &key
                                      &allow-other-keys)
  (when (thing-at-point 'string)
    (forward-sexp)))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'attr-map?))
                                      tag
                                      inherited-site
                                      &key
                                      &allow-other-keys)
  (when (looking-at "{")
    (forward-sexp)))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'key-function))
                                      tag
                                      inherited-site
                                      &key
                                      &allow-other-keys)
  (-nomis/ec-check-movement-possible (cons 'key-function tag)
                                     #'forward-sexp
                                     #'backward-up-list)
  (-nomis/ec-walk-and-overlay-v3)
  (forward-sexp))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'fn-bindings))
                                      tag
                                      inherited-site
                                      &key
                                      &allow-other-keys)
  (save-excursion
    (nomis/ec-down-list (cons 'e/fn-bindings tag))
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-skip-metadata)
      ;; Slighly unpleasant use of `setq`. Maybe this could be rewritten
      ;; to use recursion instead of iteration.
      (setq *-nomis/ec-bound-vars*
            (append (-nomis/ec-binding-structure->vars)
                    *-nomis/ec-bound-vars*))
      (forward-sexp)))
  (forward-sexp))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql 'let-bindings))
                                      tag
                                      inherited-site
                                      &key rhs-site no-bind?
                                      &allow-other-keys)
  (cl-assert (member rhs-site '(nil nec/client nec/server nec/neutral nec/inherit)))
  (save-excursion
    (let* ((tag (cons 'let-bindings tag)))
      (nomis/ec-down-list tag)
      (while (-nomis/ec-can-forward-sexp?)
        ;; Note the LHS of the binding:
        (-nomis/ec-bof)
        (-nomis/ec-skip-metadata)
        (unless no-bind?
          ;; Slighly unpleasant use of `setq`. Maybe this could be rewritten
          ;; to use recursion instead of iteration.
          (setq *-nomis/ec-bound-vars*
                (append (-nomis/ec-binding-structure->vars)
                        *-nomis/ec-bound-vars*)))
        (forward-sexp)
        ;; Walk the RHS of the binding, if there is one:
        (when (-nomis/ec-can-forward-sexp?)
          (-nomis/ec-bof)
          (-nomis/ec-skip-metadata)
          (let* ((new-site (-nomis/ec-transmogrify-site rhs-site
                                                        inherited-site))
                 (*-nomis/ec-default-site* new-site))
            (-nomis/ec-with-site (;; avoid-stupid-indentation
                                  :tag (cons 'binding-rhs tag)
                                  :site new-site
                                  :description (-> 'binding-rhs
                                                   -nomis/ec->grammar-description))
              (-nomis/ec-walk-and-overlay-v3)))
          (forward-sexp)))))
  (forward-sexp))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql '&body))
                                      tag
                                      inherited-site
                                      &key site
                                      &allow-other-keys)
  (cl-assert (member site '(nil nec/client nec/server nec/neutral nec/inherit)))
  (save-excursion
    (let* ((*-nomis/ec-site-electric-locals?* t))
      ;; Each body form separately:
      (while (-nomis/ec-can-forward-sexp?)
        (-nomis/ec-bof)
        (-nomis/ec-with-site (;; avoid-stupid-indentation
                              :tag (cons 'body-form tag)
                              :site (-nomis/ec-transmogrify-site site
                                                                 inherited-site)
                              :description (-> 'body-form
                                               -nomis/ec->grammar-description))
          (-nomis/ec-walk-and-overlay-v3))
        (forward-sexp)))))

(cl-defmethod -nomis/ec-overlay-term ((term-name (eql '&args))
                                      tag
                                      inherited-site
                                      &key site
                                      &allow-other-keys)
  (cl-assert (member site '(nil nec/client nec/server nec/neutral nec/inherit)))
  (save-excursion
    ;; Each arg separately:
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-with-site (;; avoid-stupid-indentation
                            :tag (cons 'arg tag)
                            :site (-nomis/ec-transmogrify-site site
                                                               inherited-site)
                            :description (-> 'arg
                                             -nomis/ec->grammar-description))
        (-nomis/ec-walk-and-overlay-v3))
      (forward-sexp))))

;;;; ___________________________________________________________________________
;;;; ---- -nomis/ec-overlay-using-parser-spec ----

(defun -nomis/ec-log-change-of-site (operator-id
                                     old-default-site
                                     new-default-site-supplied?
                                     new-default-site)
  (when -nomis/ec-print-debug-info-to-messages-buffer?
    (when new-default-site-supplied?
      (-nomis/ec-message-no-disp
       "%s %s ---- Change of default site: %s -> %s [operator-id = %s]"
       (-nomis/ec-line-number-string)
       (make-string (* 2 *-nomis/ec-level*) ?\s)
       old-default-site
       new-default-site
       operator-id))))

(defun -nomis/ec-process-term (term-name term-opts
                                         tag site inherited-site)
  (-nomis/ec-with-site
      (;; avoid-stupid-indentation
       :tag tag
       :site (-nomis/ec-transmogrify-site site
                                          inherited-site)
       :description (-> (first tag)
                        -nomis/ec->grammar-description))
    (apply #'-nomis/ec-overlay-term
           term-name
           tag
           inherited-site
           term-opts)))

(defun -nomis/ec-process-ecase (operator-id term inherited-site)
  (when (and (listp term)
             (eq (first term) :ecase))
    (prog1
        t
      (cl-loop for (regexp . ts) in (rest term)
               when (looking-at regexp)
               return (-nomis/ec-process-terms operator-id ts inherited-site)
               ;; :LIMITATIONS-OF-THE-GRAMMAR Do you need to signal here?
               ;; Can you just create the overlay here? If not signalling, might
               ;; need to move forwards to an appropriate new position. (And
               ;; what about in other places that we signal?)
               finally (let* ((expecteds (string-join (-map #'first
                                                            (rest term))
                                                      ", "))
                              (can-forward? (-nomis/ec-can-forward-sexp?))
                              (msg (if can-forward?
                                       (format "Expected one of %s"
                                               expecteds)
                                     (format "Form came to an end when expecting one of %s"
                                             expecteds)))
                              (pos (if can-forward?
                                       (point)
                                     (save-excursion
                                       (backward-up-list)
                                       (point)))))
                         (signal '-nomis/ec-parse-error
                                 (list msg pos))))
      ;; :LIMITATIONS-OF-THE-GRAMMAR Are we at the right buffer location
      ;; for continuing?
      )))

(defun -nomis/ec-process-list (operator-id term inherited-site)
  (when (and (listp term)
             (eq (first term) :list))
    (prog1
        t
      (if (not (looking-at "("))
          (signal '-nomis/ec-parse-error
                  (list ":list parsing failed" (point)))
        (progn
          (nomis/ec-down-list '(list-parsing))
          (when (-nomis/ec-can-forward-sexp?)
            (-nomis/ec-bof))
          (-nomis/ec-process-terms operator-id (rest term) inherited-site)
          (backward-up-list)
          (forward-sexp)))
      ;; :LIMITATIONS-OF-THE-GRAMMAR Are we at the right buffer location
      ;; for continuing?
      )))

(defun -nomis/ec-process-+ (operator-id term inherited-site)
  (when (and (listp term)
             (eq (first term) :+))
    (prog1
        t
      (cl-flet ((do-one ()
                  (-nomis/ec-process-terms operator-id (rest term) inherited-site)))
        (do-one)
        ;; :LIMITATIONS-OF-THE-GRAMMAR This is relying on coming to the end of
        ;; a list -- a restriction of our grammar -- `:+` cannot be followed by
        ;; another term. What was that weird extra thing in the Clojure grammar?
        ;; See https://clojurians.slack.com/archives/C03S1KBA2/p1732491608620849
        ;; Oh, it's outside of the list anyway, so the parsing code will
        ;; actually just ignore it. No error.
        (while (-nomis/ec-can-forward-sexp?)
          (-nomis/ec-bof)
          (do-one)))
      ;; :LIMITATIONS-OF-THE-GRAMMAR Are we at the right buffer location
      ;; for continuing?
      )))

(defun -nomis/ec-process-+-list-ecase-etc ; What's a good name for this?
    (operator-id term inherited-site)
  (or (-nomis/ec-process-ecase operator-id term inherited-site)
      (-nomis/ec-process-list operator-id term inherited-site)
      (-nomis/ec-process-+ operator-id term inherited-site)))

(defun -nomis/ec-process-terms (operator-id terms inherited-site)
  (when terms
    (cl-destructuring-bind (term &rest rest-terms) terms
      (when (-nomis/ec-can-forward-sexp?)
        (-nomis/ec-bof))
      (or (-nomis/ec-process-+-list-ecase-etc operator-id term inherited-site)
          (let* ((term-name (if (atom term) term (first term)))
                 (term-opts (if (atom term) '() (rest term)))
                 (site (plist-get term-opts :site))
                 (tag (list term-name operator-id)))
            (condition-case err
                (progn
                  (-nomis/ec-debug *-nomis/ec-site* term-name)
                  (cl-flet* ((process-terms* ()
                               (-nomis/ec-process-term term-name term-opts
                                                       tag site inherited-site)
                               (-nomis/ec-process-terms operator-id
                                                        rest-terms
                                                        inherited-site)))
                    (cl-ecase term-name
                      ((operator name name? doc-string? attr-map? key-function)
                       (process-terms*))
                      ((fn-bindings let-bindings)
                       (let* ((*-nomis/ec-bound-vars* *-nomis/ec-bound-vars*))
                         (process-terms*)))
                      ((&body &args)
                       (cl-assert (null rest-terms) t)
                       (process-terms*)))))
              (-nomis/ec-parse-error
               (-nomis/ec-overlay-unparsable (second (cdr err))
                                             term-name
                                             (first (cdr err))))))))))

(cl-defun -nomis/ec-overlay-using-parser-spec
    (&key
     operator-id
     site
     site-electric-locals?
     (new-default-site nil
                       new-default-site-supplied?)
     terms)
  (cl-assert (listp terms))
  (save-excursion
    (let* ((inherited-site *-nomis/ec-site*)
           (old-default-site *-nomis/ec-default-site*)
           (*-nomis/ec-default-site* (if new-default-site-supplied?
                                         new-default-site
                                       *-nomis/ec-default-site*))
           (*-nomis/ec-site-electric-locals?*
            (or site-electric-locals?
                *-nomis/ec-site-electric-locals?*)))
      (-nomis/ec-log-change-of-site operator-id
                                    old-default-site
                                    new-default-site-supplied?
                                    new-default-site)
      (-nomis/ec-with-site (;; avoid-stupid-indentation
                            :tag (list operator-id)
                            :site site
                            :description (-> operator-id
                                             -nomis/ec->grammar-description))
        (nomis/ec-down-list operator-id)
        (-nomis/ec-process-terms operator-id terms inherited-site)))))

;;;; ___________________________________________________________________________

(defun -nomis/ec-overlay-other-bracketed-form-v3 ()
  (-nomis/ec-debug *-nomis/ec-site* 'data-structure-or-hosted-call)
  (save-excursion
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag (list 'data-structure-or-hosted-call)
                          :site *-nomis/ec-default-site*
                          :description (-> 'data-structure-or-hosted-call
                                           -nomis/ec->grammar-description))
      (nomis/ec-down-list 'data-structure-or-hosted-call)
      (while (-nomis/ec-can-forward-sexp?)
        (-nomis/ec-bof)
        (-nomis/ec-walk-and-overlay-v3)
        (forward-sexp)))))

(defun -nomis/ec-overlay-non-descended-form ()
  (-nomis/ec-debug *-nomis/ec-site* 'symbol-number-etc)
  (let* ((sym (thing-at-point 'symbol t)))
    (cond ((null sym)
           (unless (thing-at-point 'string t)
             (let* ((sexp (thing-at-point 'sexp t)))
               (-nomis/ec-message-no-disp
                "nomis-electric-clojure-mode: Line %s: Expected a symbol-number-etc but got %s"
                (-nomis/ec-line-number-string)
                sexp))))
          ((equal sym "'")
           (-nomis/ec-with-site (;; avoid-stupid-indentation
                                 :tag (list 'quoted-form)
                                 :site *-nomis/ec-default-site*
                                 :description (-> 'quoted-form
                                                  -nomis/ec->grammar-description)
                                 :print-env? t)
             ;; Nothing more.
             ))
          ((or (looking-at
                -nomis/ec-electric-function-name-regexp-incl-symbol-end)
               (and (not *-nomis/ec-site-electric-locals?*)
                    (member sym *-nomis/ec-bound-vars*)))
           (-nomis/ec-with-site (;; avoid-stupid-indentation
                                 :tag (list 'unsited-single-item)
                                 :site 'nec/neutral
                                 :description (-> 'unsited-single-item
                                                  -nomis/ec->grammar-description)
                                 :print-env? t)
             ;; Nothing more.
             ))
          (t
           (-nomis/ec-with-site (;; avoid-stupid-indentation
                                 :tag (list 'sited-single-item)
                                 :site *-nomis/ec-default-site*
                                 :description (-> 'sited-single-item
                                                  -nomis/ec->grammar-description)
                                 :print-env? t)
             ;; Nothing more.
             )))))

(defun -nomis/ec-operator-call-regexp (operator-regexp)
  (concat "(\\([[:space:]]\\|\n\\)*"
          operator-regexp
          "\\_>"))

(rx-define -nomis/ec-symbol-char-no-slash-rx
  (any upper
       lower
       digit
       "-$&*+_<>'.=?!"))

(defconst -nomis/ec-symbol-no-slash-regexp
  (rx (+ -nomis/ec-symbol-char-no-slash-rx)))

(rx-define -nomis/ec-electric-function-name-rx
  (seq (? (seq (+ -nomis/ec-symbol-char-no-slash-rx)
               "/"))
       (seq upper
            (* -nomis/ec-symbol-char-no-slash-rx))))

(defconst -nomis/ec-electric-function-name-regexp
  (rx -nomis/ec-electric-function-name-rx))

(defconst -nomis/ec-electric-function-name-regexp-incl-symbol-end
  ;; Ugh. This shows that some naming is wrong.
  (concat -nomis/ec-electric-function-name-regexp "\\_>"))

(defvar -nomis/ec-regexp->parser-spec '())

;; Some useful things for debugging:

;; (length -nomis/ec-regexp->parser-spec)

;; (mapcar (lambda (entry) (-> entry cdr (plist-get :operator-id)))
;;         -nomis/ec-regexp->parser-spec)

;; (nth 3 -nomis/ec-regexp->parser-spec)

(cl-defun nomis/ec-add-parser-spec ((&whole spec-and-other-bits
                                            &key
                                            operator-id
                                            operator
                                            regexp?
                                            site
                                            site-electric-locals?
                                            new-default-site
                                            terms))
  "Add a spec for parsing Elecric Clojure code.

- See uses at the end of this file for the built-in parsers.

- OPERATOR can be an ordinary string or a regexp. This is controlled
  by REGEXP?.

- OPERATOR-ID defaults to OPERATOR. When REGEXP? is true
  OPERATOR-ID must be supplied.

- Order is important -- first match wins.

- If there is an existing entry for the same OPERATOR, it is replaced;
  otherwise a new entry is added at the end. New entries are created
  at the end so that the (likely) most common operators (the built-in
  ones) are found quickly to get efficient look-ups.

- If you are developing new parsers you can end up with a different
  order to when you reload from scratch. The function
  NOMIS/EC-RESET-TO-BUILT-IN-PARSER-SPECS will be useful."
  (cl-assert (symbolp operator-id) t)
  (cl-assert (stringp operator) t)
  (cl-assert (member new-default-site '(nil nec/client nec/server)) t)
  (let* ((operator-regexp (if regexp? operator (regexp-quote operator)))
         (regexp (-nomis/ec-operator-call-regexp operator-regexp))
         (spec (-> spec-and-other-bits
                   (-nomis/ec-plist-remove :operator)
                   (-nomis/ec-plist-remove :regexp?)))
         (new-entry (cons regexp spec)))
    (let* ((existing-operator-id? nil))
      (setq -nomis/ec-regexp->parser-spec
            (cl-loop
             for old-entry in -nomis/ec-regexp->parser-spec
             collect (cl-destructuring-bind (regexp . spec) old-entry
                       (if (equal operator-id (plist-get spec :operator-id))
                           (progn (setq existing-operator-id? t)
                                  new-entry)
                         old-entry))))
      (unless existing-operator-id?
        (setq -nomis/ec-regexp->parser-spec
              (append -nomis/ec-regexp->parser-spec
                      (list new-entry)))))))

(defun -nomis/ec-walk-and-overlay-v3 ()
  (-nomis/ec-skip-metadata)
  (let* ((case-fold-search nil))
    (or (let* ((*-nomis/ec-site-electric-locals?* nil))
          (cl-loop for (regexp . spec) in -nomis/ec-regexp->parser-spec
                   when (looking-at regexp)
                   return (progn
                            (apply #'-nomis/ec-overlay-using-parser-spec spec)
                            t)))
        (cond
         ((-nomis/ec-looking-at-start-of-form-to-descend?)
          (let* ((*-nomis/ec-site-electric-locals?* t))
            (-nomis/ec-overlay-other-bracketed-form-v3)))
         (t
          (-nomis/ec-overlay-non-descended-form))))))

(defun -nomis/ec-walk-and-overlay-any-version ()
  (cond ; See avoid-case-bug-with-keywords at top of file.
   ((eq -nomis/ec-electric-version :v2)
    (-nomis/ec-walk-and-overlay-v2))
   ((eq -nomis/ec-electric-version :v3)
    (-nomis/ec-walk-and-overlay-v3))
   (t (error "Bad case: -nomis/ec-electric-version: %s"
             -nomis/ec-electric-version))))

(defun -nomis/ec-buffer-has-text? (s)
  (save-excursion (goto-char 0)
                  (search-forward s
                                  nomis/ec-bound-for-electric-require-search
                                  t)))

(defun -nomis/ec-explicit-electric-version ()
  (cond ((-nomis/ec-buffer-has-text? "[hyperfiddle.electric3")
         :v3)
        ((-nomis/ec-buffer-has-text? "[hyperfiddle.electric")
         :v2)))

(defvar -nomis/ec-noted-explicit-electric-version nil
  "Used when auto-enabling the mode, to avoid searching the buffer twice.")
(make-variable-buffer-local '-nomis/ec-noted-explicit-electric-version)

(defun -nomis/ec-detect-electric-version ()
  (let* ((v (or -nomis/ec-noted-explicit-electric-version
                (-nomis/ec-explicit-electric-version)
                :v3)))
    (setq -nomis/ec-noted-explicit-electric-version nil)
    (setq -nomis/ec-electric-version v)
    ;; This blats messages when using the `nomis/ec-toggle-xxxx` commands.
    ;; What's the downside of not doing this? (For example, we do get the
    ;; version reported when enabling the mode and when reverting a buffer.)
    ;; (message "Electric version = %s"
    ;;          (string-replace ":" "" (symbol-name v)))
    ))

(defun -nomis/ec-overlay-region (start end)
  (when -nomis/ec-print-debug-info-to-messages-buffer?
    (-nomis/ec-message-no-disp "________________________________")
    (-nomis/ec-message-no-disp "==== -nomis/ec-overlay-region %s %s" start end))
  (unless -nomis/ec-electric-version
    (-nomis/ec-detect-electric-version))
  (save-excursion
    (goto-char start)
    (unless (-nomis/ec-at-top-level?) (beginning-of-defun))
    (let* ((start-2 (point))
           (end-2 (save-excursion (goto-char end)
                                  (unless (-nomis/ec-at-top-level?)
                                    (end-of-defun))
                                  (point))))
      (remove-overlays start-2 end-2 'category 'nomis/ec-overlay)
      (while (and (< (point) end-2)
                  (-nomis/ec-can-forward-sexp?))
        (-nomis/ec-bof)
        (-nomis/ec-walk-and-overlay-any-version)
        (forward-sexp))
      (-nomis/ec-feedback-flash start end start-2 end-2)
      ;; (-nomis/ec-message-no-disp "*-nomis/ec-n-lumps-in-current-update* = %s"
      ;;                            *-nomis/ec-n-lumps-in-current-update*)
      `(jit-lock-bounds ,start-2 . ,end-2))))

;;;; ___________________________________________________________________________

(defvar -nomis/ec-buffers '()
  "A list of all buffers where `nomis-electric-clojure-mode` is
turned on.

This is used when reverting a buffer, when we reapply the mode.

This is very DIY. Is there a better way?")

(defun -nomis/ec-enable ()
  (cl-pushnew (current-buffer) -nomis/ec-buffers)
  ;; Note: To get a debugger up when there are errors, use
  ;; `jit-lock-debug-mode`.
  ;; Hmmmm, that doesn't seem to work reliably.
  ;; Instead try this in an Electric Clojure buffer:
  ;; (-nomis/ec-overlay-region (point-min) (point-max))
  (jit-lock-register '-nomis/ec-overlay-region t))

(defun -nomis/ec-disable (&optional reverting?)
  (unless reverting?
    (setq -nomis/ec-buffers (cl-remove (current-buffer) -nomis/ec-buffers)))
  (setq -nomis/ec-electric-version nil) ; so we will re-detect this
  (jit-lock-unregister '-nomis/ec-overlay-region)
  (remove-overlays nil nil 'category 'nomis/ec-overlay))

(defun -nomis/ec-before-revert ()
  (-nomis/ec-disable t))

(defun -nomis/ec-after-revert ()
  (when (member (current-buffer) -nomis/ec-buffers)
    (nomis-electric-clojure-mode)))

(define-minor-mode nomis-electric-clojure-mode
  "Color Electric Clojure client code regions and server code regions."
  :init-value nil
  (if nomis-electric-clojure-mode
      (progn
        (-nomis/ec-update-faces)
        (-nomis/ec-enable)
        (add-hook 'before-revert-hook '-nomis/ec-before-revert nil t)
        (add-hook 'after-revert-hook '-nomis/ec-after-revert nil t)
        (-nomis/ec-detect-electric-version)
        (message "Nomis-Electric-Clojure mode enabled in current buffer; Electric version = %s"
                 (string-replace ":"
                                 ""
                                 (symbol-name -nomis/ec-electric-version))))
    (progn
      (-nomis/ec-disable)
      (remove-hook 'before-revert-hook '-nomis/ec-before-revert t)
      (remove-hook 'after-revert-hook '-nomis/ec-after-revert t))))

;;;; ___________________________________________________________________________
;;;; Auto-activation of the mode

(defun -nomis/ec-auto-enable-if-electric ()
  (when nomis/ec-auto-enable?
    (let* ((v (-nomis/ec-explicit-electric-version)))
      (when v
        (setq -nomis/ec-noted-explicit-electric-version v)
        (nomis-electric-clojure-mode)))))

(add-hook 'clojurec-mode-hook
          '-nomis/ec-auto-enable-if-electric)

;;;; ___________________________________________________________________________
;;;; ---- Interactive commands ----

(defun -nomis/ec-redraw ()
  (-nomis/ec-disable)
  (-nomis/ec-enable))

(defun -nomis/ec-redraw-all-buffers ()
  (dolist (b (buffer-list))
    (with-current-buffer b
      (when nomis-electric-clojure-mode
        (-nomis/ec-redraw)))))

(defun -nomis/ec-check-nomis-electric-clojure-mode ()
  (when (not nomis-electric-clojure-mode)
    (user-error "nomis-electric-clojure-mode is not turned on")))

(defun nomis/ec-redetect-electric-version ()
  (interactive)
  (if (not nomis-electric-clojure-mode)
      (nomis-electric-clojure-mode)
    (-nomis/ec-redraw)))

(defun nomis/ec-toggle-debug-show-grammar-tooltips ()
  (interactive)
  (setq nomis/ec-show-grammar-tooltips?
        (not nomis/ec-show-grammar-tooltips?))
  (-nomis/ec-redraw-all-buffers)
  (message "%s grammar tooltips"
           (if nomis/ec-show-grammar-tooltips? "Showing" "Not showing")))

(defun nomis/ec-toggle-color-initial-whitespace ()
  (interactive)
  (setq nomis/ec-color-initial-whitespace?
        (not nomis/ec-color-initial-whitespace?))
  (-nomis/ec-redraw-all-buffers)
  (message "%s initial whitespace"
           (if nomis/ec-color-initial-whitespace? "Showing" "Not showing")))

(defun nomis/ec-toggle-use-underline ()
  (interactive)
  (setq nomis/ec-use-underline? (not nomis/ec-use-underline?))
  (-nomis/ec-update-faces)
  (message "Using %s to show coloring"
           (if nomis/ec-use-underline? "underline" "background")))

(defun nomis/ec-toggle-debug-show-debug-overlays ()
  (interactive)
  (setq -nomis/ec-show-debug-overlays? (not -nomis/ec-show-debug-overlays?))
  (-nomis/ec-update-faces)
  (-nomis/ec-redraw-all-buffers)
  (message "%s debug overlays"
           (if -nomis/ec-show-debug-overlays? "Showing" "Not showing")))

(defun nomis/ec-cycle-options ()
  "Cycle between combinations of `nomis/ec-color-initial-whitespace?` and
`nomis/ec-use-underline?`."
  (interactive)
  (if (not nomis-electric-clojure-mode)
      (nomis-electric-clojure-mode)
    ;; If we add more options, can generalise this. But it might not be very
    ;; usable for more than two options -- too many things to cycle through.
    (let* ((v1 (if nomis/ec-color-initial-whitespace? 1 0))
           (v2 (if nomis/ec-use-underline? 1 0))
           (v (+ v1 (* 2 v2)))
           (new-v (mod (1+ v) 4)))
      (setq nomis/ec-color-initial-whitespace? (not (zerop (logand 1 new-v))))
      (setq nomis/ec-use-underline?            (not (zerop (logand 2 new-v))))
      (-nomis/ec-update-faces)
      (-nomis/ec-redraw-all-buffers))))

(defun nomis/ec-toggle-debug-feedback-flash ()
  (interactive)
  (setq -nomis/ec-give-debug-feedback-flash?
        (not -nomis/ec-give-debug-feedback-flash?))
  (message "Debug feedback flash turned %s"
           (if -nomis/ec-give-debug-feedback-flash? "on" "off")))

(defun nomis/ec-report-overlays ()
  (interactive)
  (-nomis/ec-check-nomis-electric-clojure-mode)
  (let* ((all-ovs (overlays-in (point-min) (point-max)))
         (ovs (cl-remove-if-not (lambda (ov)
                                  (eq 'nomis/ec-overlay
                                      (overlay-get ov 'category)))
                                all-ovs)))
    (-nomis/ec-message-no-disp "----------------")
    (dolist (ov ovs)
      (let* ((ov-start (overlay-start ov))
             (ov-end   (overlay-end ov))
             (end      (min ov-end
                            (save-excursion
                              (goto-char ov-start)
                              (pos-eol)))))
        (-nomis/ec-message-no-disp "%s %s %s%s -- %s"
                                   (overlay-get ov 'priority)
                                   ov
                                   (buffer-substring ov-start end)
                                   (if (> ov-end end)
                                       "..."
                                     "")
                                   (overlay-get ov 'nomis/tag))))
    (message "No. of overlays = %s" (length ovs))))

(defun nomis/ec-toggle-debug-print-debug-info-to-messages-buffer ()
  (interactive)
  (setq -nomis/ec-print-debug-info-to-messages-buffer?
        (not -nomis/ec-print-debug-info-to-messages-buffer?))
  (message "%s debug info to *Messages* buffer"
           (if -nomis/ec-print-debug-info-to-messages-buffer?
               "Printing"
             "Not printing")))

(defun nomis/ec-toggle-debug-show-places-for-metadata ()
  (interactive)
  (setq -nomis/ec-debug-show-places-for-metadata?
        (not -nomis/ec-debug-show-places-for-metadata?))
  (-nomis/ec-redraw-all-buffers)
  (message "%s places for metadata"
           (if -nomis/ec-debug-show-places-for-metadata? "Showing" "Not showing")))

;;;; ___________________________________________________________________________
;;;; Built-in parser specs

(defun -nomis/ec-add-built-in-parser-specs ()

  (nomis/ec-add-parser-spec '(
                              :operator-id           :e/client
                              :operator              "e/client"
                              :site                  nec/client
                              :new-default-site      nec/client
                              :site-electric-locals? t
                              :terms                 (operator
                                                      &body)))

  (nomis/ec-add-parser-spec '(
                              :operator-id           :e/server
                              :operator              "e/server"
                              :site                  nec/server
                              :new-default-site      nec/server
                              :site-electric-locals? t
                              :terms                 (operator
                                                      &body)))

  (nomis/ec-add-parser-spec `(
                              :operator-id :dom/xxxx
                              :operator    ,(concat "dom/"
                                                    -nomis/ec-symbol-no-slash-regexp)
                              :regexp?     t
                              :terms       ((operator :site nec/client)
                                            &body)))

  (nomis/ec-add-parser-spec '(
                              :operator-id      :e/defn
                              :operator         "e/defn"
                              :site             nec/neutral
                              :new-default-site nil
                              :terms            (operator
                                                 name
                                                 doc-string?
                                                 attr-map?
                                                 (:ecase ("\\["
                                                          fn-bindings
                                                          &body)
                                                         ("("
                                                          (:+
                                                           (:list fn-bindings
                                                                  &body))))
                                                 ;; :LIMITATIONS-OF-THE-GRAMMAR
                                                 ;; Not working -- grammar
                                                 ;; limitations. Oh, and also
                                                 ;; not supported by Electric
                                                 ;; Clojure (on 2025-03-24).
                                                 attr-map?)))

  (nomis/ec-add-parser-spec '(
                              :operator-id      :e/fn
                              :operator         "e/fn"
                              :site             nec/neutral
                              :new-default-site nil
                              :terms            (operator
                                                 name?
                                                 (:ecase ("\\["
                                                          fn-bindings
                                                          &body)
                                                         ("("
                                                          (:+
                                                           (:list fn-bindings
                                                                  &body)))))))

  (nomis/ec-add-parser-spec '(
                              :operator-id :let
                              :operator    "let"
                              :terms       (operator
                                            (let-bindings :site nec/neutral
                                                          :rhs-site nec/inherit)
                                            &body)))

  (nomis/ec-add-parser-spec '(
                              :operator-id :binding
                              :operator    "binding"
                              :terms       (operator
                                            (let-bindings :site nec/neutral
                                                          :rhs-site nec/inherit
                                                          :no-bind? t)
                                            &body)))

  (nomis/ec-add-parser-spec '(
                              :operator-id :e/for
                              :operator    "e/for"
                              :terms       (operator
                                            (let-bindings :site nec/neutral
                                                          :rhs-site nec/inherit)
                                            &body)))

  (nomis/ec-add-parser-spec '(
                              :operator-id :e/for-by
                              :operator    "e/for-by"
                              :terms       (operator
                                            key-function
                                            (let-bindings :site nec/neutral
                                                          :rhs-site nec/inherit)
                                            &body)))

  (nomis/ec-add-parser-spec `(
                              :operator-id :electric-call
                              :operator    ,-nomis/ec-electric-function-name-regexp
                              :regexp?     t
                              :site        nec/neutral
                              :terms       (operator
                                            &args)))

  (nomis/ec-add-parser-spec '(
                              :operator-id :electric-lambda-in-fun-position
                              :operator    "(e/fn" ; Note the open parenthesis here, for lambda in function position.
                              :site        nec/neutral
                              :terms       (operator
                                            &args))))

(-nomis/ec-add-built-in-parser-specs)

(defun nomis/ec-reset-to-built-in-parser-specs ()
  ;; Useful when developing new parser specs.
  (setq -nomis/ec-regexp->parser-spec '())
  (-nomis/ec-add-built-in-parser-specs)
  t ; avoid returning a large value
  )

;;;; ___________________________________________________________________________

(provide 'nomis-electric-clojure)
