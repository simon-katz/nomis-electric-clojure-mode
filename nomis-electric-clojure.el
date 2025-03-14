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

;;;; ___________________________________________________________________________

(defun -nomis/ec-compute-client-face ()
  (if nomis/ec-use-underline?
      'nomis/ec-client-face/using-underline
    'nomis/ec-client-face/using-background))

(defun -nomis/ec-compute-server-face ()
  (if nomis/ec-use-underline?
      'nomis/ec-server-face/using-underline
    'nomis/ec-server-face/using-background))

(defface -nomis/ec-client-face
  `((t ,(list :inherit (-nomis/ec-compute-client-face)))) ; set by `-nomis/ec-update-faces`
  "Face for Electric Clojure client code.")

(defface -nomis/ec-server-face
  `((t ,(list :inherit (-nomis/ec-compute-server-face)))) ; set by `-nomis/ec-update-faces`
  "Face for Electric Clojure server code.")

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

(defun -nomis/ec-update-faces ()
  (set-face-attribute '-nomis/ec-client-face nil
                      :inherit
                      (-nomis/ec-compute-client-face))
  (set-face-attribute '-nomis/ec-server-face nil
                      :inherit
                      (-nomis/ec-compute-server-face)))

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
                                   (cl-case 2
                                     (1 (-nomis/ec-pad-or-truncate-string
                                         s
                                         32))
                                     (2 (-nomis/ec-pad-string s 32))))
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

(defun -nomis/ec-make-overlay (tag nesting-level face start end)
  ;; (-nomis/ec-debug "MAKE-OVERLAY")
  (let* ((ov (make-overlay start end nil t nil)))
    (overlay-put ov 'nomis/tag tag)
    (overlay-put ov 'category 'nomis/ec-overlay)
    (overlay-put ov 'face face)
    (overlay-put ov 'evaporate t)
    (unless nomis/ec-color-initial-whitespace?
      ;; We have multiple overlays in the same place, so we need to
      ;; specify their priority.
      (overlay-put ov 'priority (cons nil nesting-level)))
    ov))

(defun -nomis/ec-overlay-lump (tag site nesting-level start end)
  (-nomis/ec-debug "OVERLAY-LUMP")
  (if (= start end)
      (-nomis/ec-debug "EMPTY-LUMP")
    (cl-incf *-nomis/ec-n-lumps-in-current-update*)
    (let* ((face (cl-ecase site
                   (:client  '-nomis/ec-client-face)
                   (:server  '-nomis/ec-server-face)
                   (:neutral '-nomis/ec-neutral-face))))
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
            (-nomis/ec-make-overlay tag nesting-level face start end))
        (save-excursion
          (while (< (point) end)
            (let* ((start-2 (point))
                   (end-2 (min end
                               (progn (end-of-line) (point)))))
              (unless (= start-2 end-2) ; don't create overlays of zero length
                (-nomis/ec-make-overlay tag nesting-level face start-2 end-2))
              (unless (eobp) (forward-char))
              (when (bolp)
                (back-to-indentation)))))))))

;;;; ___________________________________________________________________________
;;;; ---- Parse and overlay helpers ----

(defun -nomis/ec-checking-movement-possible* (desc move-fn overlay-fn)
  (save-excursion
    (condition-case _
        (funcall move-fn)
      (error (-nomis/ec-message-no-disp
              "nomis-electric-clojure: Failed to parse %s"
              desc))))
  (funcall overlay-fn))

(cl-defmacro -nomis/ec-checking-movement-possible ((desc move-form) &body body)
  (declare (indent 1))
  `(-nomis/ec-checking-movement-possible* ,desc
                                          (lambda () ,move-form)
                                          (lambda () ,@body)))

(defun -nomis/ec-bof ()
  (forward-sexp)
  (backward-sexp))

(defun -nomis/ec-with-site* (tag site end print-env? f)
  (cl-assert site)
  (-nomis/ec-debug tag nil print-env?)
  (let* ((start (point))
         (end (or end
                  (save-excursion (when (-nomis/ec-can-forward-sexp?)
                                    (forward-sexp))
                                  (point))))
         (*-nomis/ec-level* (1+ *-nomis/ec-level*)))
    (if (eq site *-nomis/ec-site*)
        ;; No need for a new overlay.
        (funcall f)
      (let* ((*-nomis/ec-site* site))
        (-nomis/ec-overlay-lump tag site *-nomis/ec-level* start end)
        (funcall f)))))

(cl-defmacro -nomis/ec-with-site ((;; TODO: Make all of these keyword args
                                   tag site &optional end print-env?)
                                  &body body)
  (declare (indent 1))
  `(-nomis/ec-with-site* ,tag ,site ,end ,print-env? (lambda () ,@body)))

(defun -nomis/ec-overlay-args-of-form ()
  (-nomis/ec-debug "args-of-form")
  (save-excursion
    (down-list)
    (forward-sexp)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-debug "args-of-form--arg")
      (-nomis/ec-walk-and-overlay)
      (forward-sexp))))

(defun -nomis/ec-overlay-site (site)
  (save-excursion
    (-nomis/ec-with-site ("site" site)
      (-nomis/ec-overlay-args-of-form))))

(defun -nomis/ec-overlay-body (site)
  (-nomis/ec-debug "body")
  (save-excursion
    (when (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      ;; Whole body:
      (-nomis/ec-with-site ("body"
                            site
                            (let ((body-end
                                   (save-excursion (backward-up-list)
                                                   (forward-sexp)
                                                   (backward-char)
                                                   (point))))
                              body-end))
        ;; Each body form:
        (while (-nomis/ec-can-forward-sexp?)
          (-nomis/ec-bof)
          (-nomis/ec-walk-and-overlay)
          (forward-sexp))))))

;; TODO: Handle destructuring in `-nomis/ec-binding-lhs->vars`.
;; TODO: Handle all syntax in `e/defn` -- eg doc strings, attr map, multiple arities
;; TODO: Handle all syntax in `e/fn` -- eg function name, same stuff as for `e/defn`.

(defun -nomis/ec-binding-lhs->vars ()
  (let* ((sym-or-nil (thing-at-point 'symbol t)))
    (unless sym-or-nil
      (-nomis/ec-message-no-disp "**** TODO: Unhandled binding LHS %s"
                                 (thing-at-point 'sexp t)))
    (list sym-or-nil)))

;;;; ___________________________________________________________________________
;;;; ---- Parse and overlay ----

(defun -nomis/ec-overlay-specially-if-symbol (tag inherited-site)
  (let* ((sym-or-nil (thing-at-point 'symbol t)))
    (if (not sym-or-nil)
        (-nomis/ec-with-site ((concat tag "-non-symbol")
                              inherited-site)
          (-nomis/ec-walk-and-overlay))
      (if (member sym-or-nil *-nomis/ec-bound-vars*)
          (-nomis/ec-with-site ((concat tag "-symbol-bound")
                                :neutral
                                nil
                                t)
            ;; Nothing more.
            )
        (-nomis/ec-with-site ((concat tag "-symbol-unbound")
                              inherited-site
                              nil
                              t)
          ;; Nothing more.
          )))))

(defun -nomis/ec-overlay-e-fn-bindings (operator)
  (save-excursion
    (-nomis/ec-checking-movement-possible (operator
                                           (down-list))
      (down-list)
      (while (-nomis/ec-can-forward-sexp?)
        (-nomis/ec-bof)
        ;; Slighly unpleasant use of `setq`. Maybe this could be rewritten
        ;; to use recursion instead of iteration.
        (setq *-nomis/ec-bound-vars*
              (append (-nomis/ec-binding-lhs->vars)
                      *-nomis/ec-bound-vars*))
        (forward-sexp))))
  (forward-sexp))

(defun -nomis-/ec-overlay-let-bindings (inherited-site operator)
  (save-excursion
    (-nomis/ec-checking-movement-possible (operator
                                           ;; TODO: Ensure that we have a list.
                                           ;;       Otherwise can skip an item.
                                           ;;       Check all uses of `down-list`.
                                           (down-list))
      (down-list)
      (while (-nomis/ec-can-forward-sexp?)
        ;; Note the LHS of the binding:
        (-nomis/ec-bof)
        ;; Slighly unpleasant use of `setq`. Maybe this could be rewritten
        ;; to use recursion instead of iteration.
        (setq *-nomis/ec-bound-vars*
              (append (-nomis/ec-binding-lhs->vars)
                      *-nomis/ec-bound-vars*))
        (forward-sexp)
        ;; Walk the RHS of the binding, if there is one:
        (when (-nomis/ec-can-forward-sexp?)
          (-nomis/ec-bof)
          (-nomis/ec-overlay-specially-if-symbol "binding-rhs"
                                                 inherited-site)
          (forward-sexp)))))
  (forward-sexp))

(cl-defun -nomis/ec-overlay-using-spec (&key apply-to
                                             operator
                                             site
                                             shape)
  (cl-assert (member apply-to '(:whole :operator)))
  (cl-assert (listp shape))
  (save-excursion
    (let* ((inherited-site *-nomis/ec-site*))
      (cl-labels ((continue (remaining-shape)
                    (when remaining-shape
                      (when (-nomis/ec-can-forward-sexp?)
                        (-nomis/ec-bof))
                      (-nomis/ec-debug (first remaining-shape))
                      (cl-ecase (first remaining-shape)

                        (operator
                         (-nomis/ec-checking-movement-possible (operator
                                                                (forward-sexp)))
                         (when (eq apply-to :operator)
                           ;; TODO: Use `list` instead of `concat`.
                           (-nomis/ec-with-site ((concat operator "-operator")
                                                 site)
                             ;; Nothing more.
                             ))
                         (forward-sexp)
                         (continue (rest remaining-shape)))

                        (name
                         (-nomis/ec-checking-movement-possible ((list
                                                                 operator
                                                                 'name)
                                                                (forward-sexp)))
                         (forward-sexp)
                         (continue (rest remaining-shape)))

                        (key-function
                         (-nomis/ec-checking-movement-possible (operator
                                                                (forward-sexp))
                           (-nomis/ec-with-site ("key-function"
                                                 inherited-site)
                             (-nomis/ec-walk-and-overlay))
                           (forward-sexp)
                           (continue (rest remaining-shape))))

                        (fn-bindings
                         (let* ((*-nomis/ec-bound-vars* *-nomis/ec-bound-vars*))
                           (-nomis/ec-overlay-e-fn-bindings operator)
                           (continue (rest remaining-shape))))

                        (let-bindings
                         (let* ((*-nomis/ec-bound-vars* *-nomis/ec-bound-vars*))
                           (-nomis-/ec-overlay-let-bindings inherited-site
                                                            operator)
                           (continue (rest remaining-shape))))

                        (body-inherit-site
                         (cl-assert (null (rest remaining-shape)))
                         (-nomis/ec-overlay-body inherited-site))

                        (body-neutral
                         (cl-assert (null (rest remaining-shape)))
                         (-nomis/ec-overlay-body :neutral))

                        (electric-call-args
                         (while (-nomis/ec-can-forward-sexp?)
                           (-nomis/ec-bof)
                           (-nomis/ec-overlay-specially-if-symbol "electric-call-arg"
                                                                  inherited-site)
                           (forward-sexp))))))
                  (do-it ()
                    (down-list)
                    (continue shape)))
        (if (eq apply-to :whole)
            (-nomis/ec-with-site (operator
                                  site)
              (do-it))
          (do-it))))))

(defun -nomis/ec-overlay-e/defn ()
  (-nomis/ec-overlay-using-spec :operator "e/defn"
                                :site     :neutral
                                :apply-to :whole
                                :shape    '(operator
                                            name
                                            fn-bindings
                                            body-neutral)))

(defun -nomis/ec-overlay-e/fn ()
  (-nomis/ec-overlay-using-spec :operator "e/fn"
                                :site     :neutral
                                :apply-to :whole
                                :shape    '(operator
                                            fn-bindings
                                            body-neutral)))

(defun -nomis/ec-overlay-dom-xxxx ()
  (-nomis/ec-overlay-using-spec :operator "dom/xxxx"
                                :site     :client
                                :apply-to :operator
                                :shape    '(operator
                                            body-inherit-site)))

(defun -nomis/ec-overlay-let (operator)
  (-nomis/ec-overlay-using-spec :operator operator
                                :site     :neutral
                                :apply-to :whole
                                :shape    '(operator
                                            let-bindings
                                            body-inherit-site)))

(defun -nomis/ec-overlay-for-by (operator)
  (-nomis/ec-debug operator)
  (save-excursion
    (-nomis/ec-overlay-using-spec :operator operator
                                  :site     :neutral
                                  :apply-to :whole
                                  :shape    '(operator
                                              key-function
                                              let-bindings
                                              body-inherit-site))))

(defun -nomis/ec-overlay-electric-call ()
  (-nomis/ec-overlay-using-spec :operator "electric-call"
                                :site     :neutral
                                :apply-to :whole
                                :shape    '(operator
                                            electric-call-args)))

(defun -nomis/ec-overlay-host-call ()
  (-nomis/ec-debug "host-call")
  ;; No need to do anything. This will already be colored (or not) by a parent
  ;; `e/client` or an `e/server`.
  )

(defun -nomis/ec-overlay-other-bracketed-form ()
  (-nomis/ec-debug "other-bracketed-form")
  (save-excursion
    (down-list)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-walk-and-overlay)
      (forward-sexp))))

(defun -nomis/ec-overlay-symbol-number-etc ()
  (-nomis/ec-debug "SYMBOL-NUMBER-ETC")
  ;; Nothing to do. Special handling of symbols is done in
  ;; `-nomis/ec-overlay-specially-if-symbol`.
  )

(defun -nomis/ec-operator-call-regexp (operator &optional no-symbol-end?)
  (concat "(\\([[:space:]]\\|\n\\)*"
          operator
          (if no-symbol-end? "" "\\_>")))

(defconst -nomis/ec-e/defn-form-regexp   (-nomis/ec-operator-call-regexp "e/defn"))
(defconst -nomis/ec-e/client-form-regexp (-nomis/ec-operator-call-regexp "e/client"))
(defconst -nomis/ec-e/server-form-regexp (-nomis/ec-operator-call-regexp "e/server"))
(defconst -nomis/ec-e/fn-form-regexp     (-nomis/ec-operator-call-regexp "e/fn"))
(defconst -nomis/ec-dom/-form-regexp     (-nomis/ec-operator-call-regexp "dom/" t))
(defconst -nomis/ec-let-form-regexp      (-nomis/ec-operator-call-regexp "let"))
(defconst -nomis/ec-binding-form-regexp  (-nomis/ec-operator-call-regexp "binding"))
(defconst -nomis/ec-e/for-form-regexp    (-nomis/ec-operator-call-regexp "e/for"))
(defconst -nomis/ec-e/for-by-form-regexp (-nomis/ec-operator-call-regexp "e/for-by"))

(defconst -nomis/ec-symbol-chars "-a-zA-Z0-9$&*+_<>/'.=?!")

(defconst -nomis/ec-host-function-name-regexp
  (concat "["
          -nomis/ec-symbol-chars
          "]*"))

(defconst -nomis/ec-electric-function-name-regexp
  (concat "[A-Z]"
          -nomis/ec-host-function-name-regexp))

(defconst -nomis/ec-e/electric-call-regexp    (-nomis/ec-operator-call-regexp
                                               -nomis/ec-electric-function-name-regexp))

(defconst -nomis/ec-e/host-call-regexp
  ;; We rely on `-nomis/ec-operator-call-regexp` being tried first.
  (-nomis/ec-operator-call-regexp -nomis/ec-host-function-name-regexp))

(defun -nomis/ec-walk-and-overlay ()
  (save-excursion
    (let* ((case-fold-search nil))
      (cl-ecase -nomis/ec-electric-version
        (:v2
         (cond
          ((looking-at -nomis/ec-e/client-form-regexp) (-nomis/ec-overlay-site :client))
          ((looking-at -nomis/ec-e/server-form-regexp) (-nomis/ec-overlay-site :server))
          ((-nomis/ec-looking-at-bracketed-sexp-start) (-nomis/ec-overlay-other-bracketed-form))))
        (:v3
         (cond
          ((looking-at -nomis/ec-e/defn-form-regexp)   (-nomis/ec-overlay-e/defn))
          ((looking-at -nomis/ec-e/fn-form-regexp)     (-nomis/ec-overlay-e/fn))
          ((looking-at -nomis/ec-e/client-form-regexp) (-nomis/ec-overlay-site :client))
          ((looking-at -nomis/ec-e/server-form-regexp) (-nomis/ec-overlay-site :server))
          ((looking-at -nomis/ec-dom/-form-regexp)     (-nomis/ec-overlay-dom-xxxx))
          ((looking-at -nomis/ec-let-form-regexp)      (-nomis/ec-overlay-let "let"))
          ((looking-at -nomis/ec-binding-form-regexp)  (-nomis/ec-overlay-let "binding"))
          ((looking-at -nomis/ec-e/for-form-regexp)    (-nomis/ec-overlay-let "e/for"))
          ((looking-at -nomis/ec-e/for-by-form-regexp) (-nomis/ec-overlay-for-by "for-by"))
          ((looking-at -nomis/ec-e/electric-call-regexp) (-nomis/ec-overlay-electric-call))
          ((looking-at -nomis/ec-e/host-call-regexp)   (-nomis/ec-overlay-host-call))
          ((-nomis/ec-looking-at-bracketed-sexp-start) (-nomis/ec-overlay-other-bracketed-form))
          (t (-nomis/ec-overlay-symbol-number-etc))))))))

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
          (-nomis/ec-walk-and-overlay)
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

(defun -nomis/ec-check-nomis-electric-clojure-mode ()
  (when (not nomis-electric-clojure-mode)
    (user-error "nomis-electric-clojure-mode is not turned on")))

(defun nomis/ec-redetect-electric-version ()
  (interactive)
  (if (not nomis-electric-clojure-mode)
      (nomis-electric-clojure-mode)
    (-nomis/ec-disable)
    (-nomis/ec-enable)))

(defun nomis/ec-toggle-color-initial-whitespace ()
  (interactive)
  (if (not nomis-electric-clojure-mode)
      (nomis-electric-clojure-mode)
    (setq nomis/ec-color-initial-whitespace?
          (not nomis/ec-color-initial-whitespace?))
    (-nomis/ec-disable)
    (-nomis/ec-enable)))

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
      (-nomis/ec-disable)
      (-nomis/ec-enable))))

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

(provide 'nomis-electric-clojure)
