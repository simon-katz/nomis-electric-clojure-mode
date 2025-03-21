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

(require 'parseclj)

;;;; ___________________________________________________________________________
;;;; Customizable things

(defcustom nomis/ec-auto-enable? t
  "Whether to turn on `nomis-electric-clojure-mode` automatically by
looking for
  `[hyperfiddle.electric :as e]`
or
  `[hyperfiddle.electric3 :as e]`
at the beginning of all .cljc buffers."
  :type 'boolean)

(defcustom nomis/ec-bound-for-electric-require-search 10000
  "How far to search in Electric Clojure source code buffers when
trying to detect the version of Electric Clojure.

This detection is done when `nomis-electric-clojure-mode` is turned on,
by looking for
  `[hyperfiddle.electric :as e]`
or
  `[hyperfiddle.electric3 :as e]`
near the beginning of the buffer.

You can re-run the auto-detection in any of the following ways:
- by running `M-x nomis/ec-redetect-electric-version`
- by turning `nomis-electric-clojure-mode` off and then back on
- by reverting the buffer."
  :type 'integer)

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
  `((t ,(list :box (list :color "Red"))))
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
  `((t ,(list :box (list :color "Red"))))
  "Face for unparsable Electric Clojure code when using underline.
This includes both bad syntax and parts of Clojure that we don't know about.")

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

(defface -nomis/ec-unparsable-face
  `((t ,(list :inherit (-nomis/ec-compute-unparsable-face)))) ; set by `-nomis/ec-update-faces`
  "Face for unparsable Electric Clojure code.")

(defun -nomis/ec-update-faces ()
  (set-face-attribute '-nomis/ec-client-face nil
                      :inherit
                      (-nomis/ec-compute-client-face))
  (set-face-attribute '-nomis/ec-server-face nil
                      :inherit
                      (-nomis/ec-compute-server-face))
  (set-face-attribute '-nomis/ec-unparsable-face nil
                      :inherit
                      (-nomis/ec-compute-unparsable-face)))

(defface -nomis/ec-neutral-face
  `((t ,(list :background "unspecified-bg"
              :underline nil)))
  "Face for Electric code that is neither specifically client code nor
specifically server code.

This can be:
- code that is either client or server code; for example:
  - code that is not lexically within `e/client` or `e/server`
  - an `(e/fn ...)`
- code that is neither client nor server; for example:
  - in Electric v3:
    - symbols that are being bound; /eg/ the LHS of `let` bindings.")

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

(defun -nomis/ec-a-few-current-chars ()
  (let* ((start (point))
         (end-of-form (save-excursion
                        (when (-nomis/ec-can-forward-sexp?)
                          (forward-sexp))
                        (point)))
         (end-of-line (pos-eol)))
    (concat (buffer-substring start end-of-line)
            (when (< end-of-line end-of-form) "▶▶▶"))))

(defvar -nomis/ec-debug? nil)

(defun -nomis/ec-debug (what &optional force? print-env?)
  (when (or force? -nomis/ec-debug?)
    (let* ((inhibit-message t))
      (-nomis/ec-message-no-disp "%s %s ---- %s %s => %s%s"
                                 (-nomis/ec-pad-string
                                  (number-to-string (line-number-at-pos))
                                  5
                                  t)
                                 (make-string (* 2 *-nomis/ec-level*) ?\s)
                                 *-nomis/ec-site*
                                 (let* ((s (with-output-to-string (princ what))))
                                   (-nomis/ec-pad-string s 32))
                                 (-nomis/ec-a-few-current-chars)
                                 (if print-env?
                                     (format " ---- env = %s" *-nomis/ec-bound-vars*)
                                   "")))))

;;;; ___________________________________________________________________________
;;;; Some utilities copied from `nomis-sexp-utils`. (I don't want to
;;;; make this package dependent on `nomis-sexp-utils`.)

(defvar -nomis/ec-regexp-for-bracketed-sexp-start
  "(\\|\\[\\|{\\|#{")

(defun -nomis/ec-looking-at-bracketed-sexp-start ()
  (looking-at -nomis/ec-regexp-for-bracketed-sexp-start))

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

(defun nomis/ec-at-or-before-sexp-start? ()
  ;; I can't get this to work with a regexp for whitespace followed by
  ;; a bracketed-sexp-start. So:
  (and (-nomis/ec-can-forward-sexp?)
       (save-excursion
         (forward-sexp)
         (backward-sexp)
         (-nomis/ec-looking-at-bracketed-sexp-start))))

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

(defvar *-nomis/ec-n-lumps-in-current-update*)

(defvar *-nomis/ec-site* :neutral
  "The site of the code currently being analysed. One of `:neutral`,
`:client` or `:server`.")

(defvar *-nomis/ec-bound-vars*)

(defvar *-nomis/ec-level* 0)

;;;; ___________________________________________________________________________
;;;; Overlay basics

(defun -nomis/ec-make-overlay (tag nesting-level face start end description)
  ;; (-nomis/ec-debug :make-overlay)
  (let* ((ov (make-overlay start end nil t nil)))
    (overlay-put ov 'nomis/tag tag)
    (overlay-put ov 'category 'nomis/ec-overlay)
    (overlay-put ov 'face face)
    (overlay-put ov 'evaporate t)
    (when description (overlay-put ov 'help-echo description))
    (unless nomis/ec-color-initial-whitespace?
      ;; We have multiple overlays in the same place, so we need to
      ;; specify their priority.
      (overlay-put ov 'priority (cons nil nesting-level)))
    ov))

(defun -nomis/ec-overlay-lump (tag site nesting-level start end description)
  (-nomis/ec-debug :overlay-lump)
  (if (= start end)
      (-nomis/ec-debug :empty-lump)
    (cl-incf *-nomis/ec-n-lumps-in-current-update*)
    (let* ((face (cond ; See avoid-case-bug-with-keywords at top of file.
                  ((eq site :client)     '-nomis/ec-client-face)
                  ((eq site :server)     '-nomis/ec-server-face)
                  ((eq site :neutral)    '-nomis/ec-neutral-face)
                  ((eq site :unparsable) '-nomis/ec-unparsable-face)
                  (t (error "Bad case")))))
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

;;;; ___________________________________________________________________________
;;;; ---- Parse and overlay helpers ----

(defun nomis/ec-down-list (desc)
  "If we are at or before the start of a bracketed s-expression, move
into that expression -- /ie/ move down one level of parentheses.
Otherwise throw an exception."
  (cond ((not (-nomis/ec-can-forward-sexp?))
         (let* ((msg (format "Missing %s" desc)))
           (error (-nomis/ec-message-no-disp "%s" msg)
                  (signal '-nomis/ec-parse-error
                          (list desc msg (save-excursion
                                           (backward-up-list)
                                           (point)))))))
        ((not (nomis/ec-at-or-before-sexp-start?))
         (let* ((msg (format "A bracketed s-expression is needed for %s"
                             desc)))
           (error (-nomis/ec-message-no-disp "%s" msg)
                  (signal '-nomis/ec-parse-error
                          (list desc msg (point))))))
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
                             desc)))
           (-nomis/ec-message-no-disp "%s" msg)
           (signal '-nomis/ec-parse-error
                   (list desc msg (progn (goto-char start)
                                         (funcall error-position-fn)
                                         (point))))))))))

(defun -nomis/ec-bof ()
  (forward-sexp)
  (backward-sexp))

(defun -nomis/ec-with-site* (tag site end description print-env? f)
  (cl-assert tag)
  (cl-assert site)
  (-nomis/ec-debug tag nil print-env?)
  (let* ((*-nomis/ec-level* (1+ *-nomis/ec-level*)))
    (if (eq site *-nomis/ec-site*)
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

(defun -nomis/ec-overlay-unparsable (pos tag description)
  (save-excursion
    (goto-char pos)
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag tag
                          :site :unparsable
                          :description description)
      ;; Nothing more.
      )))

(cl-defmacro -nomis/ec-with-site ((&key tag site end description print-env?)
                                  &body body)
  (declare (indent 1))
  `(-nomis/ec-with-site* ,tag ,site ,end ,description ,print-env?
                         (lambda () ,@body)))

(defun -nomis/ec-overlay-args-of-form ()
  (-nomis/ec-debug 'args-of-form)
  (save-excursion
    (nomis/ec-down-list 'args-of-form)
    (forward-sexp)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-debug (list 'args-of-form 'arg))
      (-nomis/ec-walk-and-overlay)
      (forward-sexp))))

(defun -nomis/ec-overlay-site (site)
  (save-excursion
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag 'site
                          :site site)
      (-nomis/ec-overlay-args-of-form))))

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

(defun -nomis/ec-overlay-specially-if-symbol (tag inherited-site)
  (let* ((sym-or-nil (thing-at-point 'symbol t)))
    (if (not sym-or-nil)
        (-nomis/ec-with-site (;; avoid-stupid-indentation
                              :tag (list tag 'non-symbol)
                              :site inherited-site)
          (-nomis/ec-walk-and-overlay))
      (if (member sym-or-nil *-nomis/ec-bound-vars*)
          (-nomis/ec-with-site (;; avoid-stupid-indentation
                                :tag (list tag 'symbol-bound)
                                :site :neutral
                                :print-env? t)
            ;; Nothing more.
            )
        (-nomis/ec-with-site (;; avoid-stupid-indentation
                              :tag (list tag 'symbol-unbound)
                              :site inherited-site
                              :print-env? t)
          ;; Nothing more.
          )))))

;;;; ___________________________________________________________________________
;;;; ---- Parse and overlay ----

(defun -nomis/ec-overlay-using-spec/operator (operator-id apply-to site)
  (-nomis/ec-check-movement-possible operator-id
                                     #'forward-sexp
                                     #'backward-up-list)
  (when (eq apply-to 'operator)
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag (list operator-id 'operator)
                          :site site)
      ;; Nothing more.
      ))
  ;; Operators don't have to be symbols; they can be lambdas. So:
  (unless (thing-at-point 'symbol)
    (-nomis/ec-walk-and-overlay)))

(defun -nomis/ec-overlay-using-spec/name (operator-id)
  (-nomis/ec-check-movement-possible (list operator-id 'name)
                                     #'forward-sexp
                                     #'backward-up-list))

(defun -nomis/ec-overlay-using-spec/key-function (operator-id
                                                  inherited-site)
  (-nomis/ec-check-movement-possible (list operator-id 'key-function)
                                     #'forward-sexp
                                     #'backward-up-list)
  (-nomis/ec-with-site (;; avoid-stupid-indentation
                        :tag :key-function
                        :site inherited-site)
    (-nomis/ec-walk-and-overlay)))

(defun -nomis/ec-overlay-using-spec/e-fn-bindings (operator-id)
  (save-excursion
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag operator-id
                          :site :neutral)
      (nomis/ec-down-list (list operator-id
                                'e/fn-bindings))
      (while (-nomis/ec-can-forward-sexp?)
        (-nomis/ec-bof)
        ;; Slighly unpleasant use of `setq`. Maybe this could be rewritten
        ;; to use recursion instead of iteration.
        (setq *-nomis/ec-bound-vars*
              (append (-nomis/ec-binding-structure->vars)
                      *-nomis/ec-bound-vars*))
        (forward-sexp)))))

(defun -nomis-/ec-overlay-using-spec/let-bindings (inherited-site operator-id)
  (save-excursion
    (-nomis/ec-with-site (;; avoid-stupid-indentation
                          :tag operator-id
                          :site :neutral)
      (nomis/ec-down-list (list operator-id
                                'let-bindings))
      (while (-nomis/ec-can-forward-sexp?)
        ;; Note the LHS of the binding:
        (-nomis/ec-bof)
        ;; Slighly unpleasant use of `setq`. Maybe this could be rewritten
        ;; to use recursion instead of iteration.
        (setq *-nomis/ec-bound-vars*
              (append (-nomis/ec-binding-structure->vars)
                      *-nomis/ec-bound-vars*))
        (forward-sexp)
        ;; Walk the RHS of the binding, if there is one:
        (when (-nomis/ec-can-forward-sexp?)
          (-nomis/ec-bof)
          (-nomis/ec-overlay-specially-if-symbol "binding-rhs"
                                                 inherited-site)
          (forward-sexp))))))

(defun -nomis/ec-overlay-using-spec/body ()
  (-nomis/ec-debug 'body)
  (save-excursion
    (when (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      ;; Each body form:
      (while (-nomis/ec-can-forward-sexp?)
        (-nomis/ec-bof)
        (-nomis/ec-walk-and-overlay)
        (forward-sexp)))))

(defun -nomis/ec-overlay-using-spec/electric-call-args (inherited-site)
  (while (-nomis/ec-can-forward-sexp?)
    (-nomis/ec-bof)
    (-nomis/ec-overlay-specially-if-symbol "electric-call-arg"
                                           inherited-site)
    (forward-sexp)))

(cl-defun -nomis/ec-overlay-using-spec (&key operator-id
                                             apply-to
                                             site
                                             shape)
  (cl-assert (or (null apply-to) (member apply-to '(whole operator))))
  (cl-assert (or (not apply-to) site))
  (cl-assert (listp shape))
  (save-excursion
    (let* ((inherited-site *-nomis/ec-site*))
      (cl-labels
          ((next (remaining-shape)
             (cl-ecase (first remaining-shape)

               (operator
                (-nomis/ec-overlay-using-spec/operator operator-id
                                                       apply-to
                                                       site)
                (forward-sexp)
                (continue (rest remaining-shape)))

               (name
                (-nomis/ec-overlay-using-spec/name operator-id)
                (forward-sexp)
                (continue (rest remaining-shape)))

               (name?
                (when (thing-at-point 'symbol)
                  (forward-sexp))
                (continue (rest remaining-shape)))

               (doc-string?
                (when (thing-at-point 'string)
                  (forward-sexp))
                (continue (rest remaining-shape)))

               (attr-map?
                (when (looking-at "{")
                  (forward-sexp))
                (continue (rest remaining-shape)))

               (key-function
                (-nomis/ec-overlay-using-spec/key-function operator-id
                                                           inherited-site)
                (forward-sexp)
                (continue (rest remaining-shape)))

               (fn-bindings
                (let* ((*-nomis/ec-bound-vars* *-nomis/ec-bound-vars*))
                  (-nomis/ec-overlay-using-spec/e-fn-bindings operator-id)
                  (forward-sexp)
                  (continue (rest remaining-shape))))

               (let-bindings
                (let* ((*-nomis/ec-bound-vars* *-nomis/ec-bound-vars*))
                  (-nomis-/ec-overlay-using-spec/let-bindings inherited-site
                                                              operator-id)
                  (forward-sexp)
                  (continue (rest remaining-shape))))

               (body
                (cl-assert (null (rest remaining-shape)))
                (-nomis/ec-overlay-using-spec/body))

               (electric-call-args
                (cl-assert (null (rest remaining-shape)))
                (-nomis/ec-overlay-using-spec/electric-call-args inherited-site))))

           (continue (remaining-shape)
             (when remaining-shape
               (when (-nomis/ec-can-forward-sexp?)
                 (-nomis/ec-bof))
               (-nomis/ec-debug (first remaining-shape))
               (condition-case err
                   (next remaining-shape)
                 (-nomis/ec-parse-error
                  (goto-char (third (cdr err)))
                  (-nomis/ec-overlay-unparsable (point)
                                                (first remaining-shape)
                                                (second (cdr err)))))))
           (do-it ()
             (nomis/ec-down-list operator-id)
             (continue shape)))
        (if (eq apply-to 'whole)
            (-nomis/ec-with-site (;; avoid-stupid-indentation
                                  :tag operator-id
                                  :site site)
              (do-it))
          (do-it))))))

(defun -nomis/ec-overlay-other-bracketed-form ()
  (-nomis/ec-debug 'other-bracketed-form)
  (save-excursion
    (nomis/ec-down-list 'other-bracketed-form)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-walk-and-overlay)
      (forward-sexp))))

(defun -nomis/ec-overlay-symbol-number-etc ()
  (-nomis/ec-debug 'symbol-number-etc)
  ;; Nothing to do. Special handling of symbols is done in
  ;; `-nomis/ec-overlay-specially-if-symbol`.
  )

(defun -nomis/ec-operator-call-regexp (operator-regexp &optional no-symbol-end?)
  (concat "(\\([[:space:]]\\|\n\\)*"
          operator-regexp
          (if no-symbol-end? "" "\\_>")))

(rx-define -nomis/ec-symbol-char-no-slash-rx
  (any upper
       lower
       digit
       "-$&*+_<>'.=?!"))

(rx-define -nomis/ec-electric-function-name-rx
  (seq (? (seq (+ -nomis/ec-symbol-char-no-slash-rx)
               "/"))
       (seq upper
            (* -nomis/ec-symbol-char-no-slash-rx))))

(defconst -nomis/ec-electric-function-name-regexp
  (rx -nomis/ec-electric-function-name-rx))

(defvar -nomis/ec-regexp->parser-spec '())

;; Some useful things for debugging:

;; (length -nomis/ec-regexp->parser-spec)

;; (mapcar (lambda (entry) (-> entry cdr (plist-get :operator-id)))
;;         -nomis/ec-regexp->parser-spec)

;; (nth 3 -nomis/ec-regexp->parser-spec)

(cl-defun nomis/ec-add-parser-spec ((&key operator
                                          no-symbol-end?
                                          regexp?
                                          (operator-id
                                           (if regexp?
                                               (error "operator-id must be supplied when regexp? is true")
                                             operator))
                                          apply-to
                                          site
                                          shape))
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
  (let* ((operator-regexp (if regexp? operator (regexp-quote operator)))
         (regexp (-nomis/ec-operator-call-regexp operator-regexp
                                                 no-symbol-end?))
         (spec (list :operator-id operator-id
                     :apply-to    apply-to
                     :site        site
                     :shape       shape))
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

(defun -nomis/ec-overlay-if-spec-ified ()
  (cl-loop for (regexp . spec) in -nomis/ec-regexp->parser-spec
           when (looking-at regexp)
           return (progn (apply #'-nomis/ec-overlay-using-spec spec)
                         t)))

(defun -nomis/ec-walk-and-overlay ()
  (save-excursion
    (let* ((case-fold-search nil))
      (cond ; See avoid-case-bug-with-keywords at top of file.
       ((eq -nomis/ec-electric-version :v2)
        (cond
         ((looking-at (-nomis/ec-operator-call-regexp "e/client"))
          (-nomis/ec-overlay-site :client))
         ((looking-at (-nomis/ec-operator-call-regexp "e/server"))
          (-nomis/ec-overlay-site :server))
         ((-nomis/ec-looking-at-bracketed-sexp-start)
          (-nomis/ec-overlay-other-bracketed-form))))
       ((eq -nomis/ec-electric-version :v3)
        (or (-nomis/ec-overlay-if-spec-ified)
            (cond
             ((-nomis/ec-looking-at-bracketed-sexp-start)
              (-nomis/ec-overlay-other-bracketed-form))
             (t
              (-nomis/ec-overlay-symbol-number-etc)))))
       (t (error "Bad case"))))))

(defun -nomis/ec-buffer-has-text? (s)
  (save-excursion (goto-char 0)
                  (search-forward s
                                  nomis/ec-bound-for-electric-require-search
                                  t)))

(defun -nomis/ec-explicit-electric-version ()
  (cond ((-nomis/ec-buffer-has-text? "[hyperfiddle.electric3 :as e]")
         :v3)
        ((-nomis/ec-buffer-has-text? "[hyperfiddle.electric :as e]")
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
    (message "Electric version = %s"
             (string-replace ":" "" (symbol-name v)))))

(defun -nomis/ec-overlay-region (start end)
  (when -nomis/ec-debug?
    (-nomis/ec-message-no-disp "________________________________")
    (-nomis/ec-message-no-disp "==== -nomis/ec-overlay-region %s %s" start end))
  (unless -nomis/ec-electric-version
    (-nomis/ec-detect-electric-version))
  (let* ((*-nomis/ec-bound-vars* '())
         (*-nomis/ec-n-lumps-in-current-update* 0))
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
          (condition-case err
              (-nomis/ec-walk-and-overlay)
            (error (-nomis/ec-message-no-disp "nomis-electric-clojure: %s"
                                              err)))
          (forward-sexp))
        (-nomis/ec-feedback-flash start end start-2 end-2)
        ;; (-nomis/ec-message-no-disp "*-nomis/ec-n-lumps-in-current-update* = %s"
        ;;                            *-nomis/ec-n-lumps-in-current-update*)
        `(jit-lock-bounds ,start-2 . ,end-2)))))

;;;; ___________________________________________________________________________

(defvar -nomis/ec-buffers '()
  "A list of all buffers where `nomis-electric-clojure-mode` is
turned on.

This is used when reverting a buffer, when we reapply the mode.

This is very DIY. Is there a better way?")

(defun -nomis/ec-enable ()
  (cl-pushnew (current-buffer) -nomis/ec-buffers)
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
        (add-hook 'after-revert-hook '-nomis/ec-after-revert nil t))
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

(defun nomis/ec-toggle-color-initial-whitespace ()
  (interactive)
  (if (not nomis-electric-clojure-mode)
      (nomis-electric-clojure-mode)
    (setq nomis/ec-color-initial-whitespace?
          (not nomis/ec-color-initial-whitespace?))
    (-nomis/ec-redraw-all-buffers)))

(defun nomis/ec-toggle-use-underline ()
  (interactive)
  (if (not nomis-electric-clojure-mode)
      (nomis-electric-clojure-mode)
    (setq nomis/ec-use-underline? (not nomis/ec-use-underline?))
    (-nomis/ec-update-faces)))

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
  (if (not nomis-electric-clojure-mode)
      (nomis-electric-clojure-mode)
    (setq -nomis/ec-give-debug-feedback-flash?
          (not -nomis/ec-give-debug-feedback-flash?)))
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

;;;; ___________________________________________________________________________
;;;; Built-in parser specs

(defun -nomis/ec-add-built-in-parser-specs ()
  (nomis/ec-add-parser-spec '(
                              :operator "e/client"
                              :site     :client
                              :apply-to whole
                              :shape    (operator
                                         body)))
  (nomis/ec-add-parser-spec '(
                              :operator "e/server"
                              :site     :server
                              :apply-to whole
                              :shape    (operator
                                         body)))
  (nomis/ec-add-parser-spec '(
                              :operator       "dom/"
                              :no-symbol-end? t
                              :site           :client
                              :apply-to       operator
                              :shape          (operator
                                               body)))
  (nomis/ec-add-parser-spec '(
                              :operator "e/defn"
                              :site     :neutral
                              :apply-to whole
                              :shape    (operator
                                         name
                                         doc-string?
                                         attr-map?
                                         fn-bindings
                                         body)))
  (nomis/ec-add-parser-spec '(
                              :operator "e/fn"
                              :site     :neutral
                              :apply-to whole
                              :shape    (operator
                                         name?
                                         fn-bindings
                                         body)))
  (nomis/ec-add-parser-spec '(
                              :operator "let"
                              :shape    (operator
                                         let-bindings
                                         body)))
  (nomis/ec-add-parser-spec '(
                              :operator "binding"
                              :shape    (operator
                                         let-bindings
                                         body)))
  (nomis/ec-add-parser-spec '(
                              :operator "e/for"
                              :shape    (operator
                                         let-bindings
                                         body)))
  (nomis/ec-add-parser-spec '(
                              :operator "e/for-by"
                              :shape    (operator
                                         key-function
                                         let-bindings
                                         body)))
  (nomis/ec-add-parser-spec `(
                              :operator-id electric-call
                              :operator    ,-nomis/ec-electric-function-name-regexp
                              :regexp?     t
                              :site        :neutral
                              :apply-to    whole
                              :shape       (operator
                                            electric-call-args)))
  (nomis/ec-add-parser-spec '(
                              :operator-id electric-lambda-in-fun-position
                              :operator    "(e/fn" ; Note the open parenthesis here, for lambda in function position.
                              :site        :neutral
                              :apply-to    whole
                              :shape       (operator
                                            electric-call-args))))

(-nomis/ec-add-built-in-parser-specs)

(defun nomis/ec-reset-to-built-in-parser-specs ()
  ;; Useful when developing new parser specs.
  (setq -nomis/ec-regexp->parser-spec '())
  (-nomis/ec-add-built-in-parser-specs)
  t ; avoid returning a large value
  )

;;;; ___________________________________________________________________________

(provide 'nomis-electric-clojure)
