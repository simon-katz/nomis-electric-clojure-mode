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

(defface -nomis/ec-client-face
  `() ; set by `-nomis/ec-update-faces`
  "Face for Electric Clojure client code.")

(defface -nomis/ec-server-face
  `() ; set by `-nomis/ec-update-faces`
  "Face for Electric Clojure server code.")

(defface -nomis/ec-neutral-face
  `((t ,(list :inherit 'default)))
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
                      (if nomis/ec-use-underline?
                          'nomis/ec-client-face/using-underline
                        'nomis/ec-client-face/using-background))
  (set-face-attribute '-nomis/ec-server-face nil
                      :inherit
                      (if nomis/ec-use-underline?
                          'nomis/ec-server-face/using-underline
                        'nomis/ec-server-face/using-background)))

;;;; ___________________________________________________________________________

(defvar -nomis/ec-electric-version)
(make-variable-buffer-local '-nomis/ec-electric-version)

;;;; ___________________________________________________________________________

(defun nomis/ec-message-no-disp (format-string &rest args)
  (let* ((inhibit-message t))
    (apply #'message format-string args)))

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

(defvar *-nomis/ec-level* 0)

;;;; ___________________________________________________________________________
;;;; Overlay basics

(defun -nomis/ec-make-overlay (nesting-level face start end)
  (let* ((ov (make-overlay start end nil t nil)))
    (overlay-put ov 'category 'nomis/ec-overlay)
    (overlay-put ov 'face face)
    (overlay-put ov 'evaporate t)
    (unless nomis/ec-color-initial-whitespace?
      ;; We have multiple overlays in the same place, so we need to
      ;; specify their priority.
      (overlay-put ov 'priority (cons nil nesting-level)))
    ov))

(defun -nomis/ec-overlay-single-lump (site nesting-level start end)
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
          (-nomis/ec-make-overlay nesting-level face start end))
      (save-excursion
        (while (< (point) end)
          (let* ((start-2 (point))
                 (end-2 (min end
                             (progn (end-of-line) (1+ (point))))))
            (unless (= (1+ start-2) end-2) ; don't color blank lines
              (-nomis/ec-make-overlay nesting-level face start-2 end-2))
            (unless (eobp) (forward-char))
            (when (bolp)
              (back-to-indentation))))))))

;;;; ___________________________________________________________________________
;;;; ---- Parse and overlay helpers ----

(defun -nomis/ec-checking-movement* (desc move-fn overlay-fn)
  (condition-case _
      (funcall move-fn)
    (error (nomis/ec-message-no-disp
            "nomis-electric-clojure: Failed to parse %s"
            desc)))
  (funcall overlay-fn))

(cl-defmacro -nomis/ec-checking-movement ((desc move-form) &body body)
  (declare (indent 1))
  `(-nomis/ec-checking-movement* ,desc
                                 (lambda () ,move-form)
                                 (lambda () ,@body)))

(defun -nomis/ec-bof ()
  (forward-sexp)
  (backward-sexp))

(defun -nomis/ec-with-site* (site end f)
  (let* ((start (point))
         (end (or end
                  (save-excursion (forward-sexp) (point))))
         (*-nomis/ec-level* (1+ *-nomis/ec-level*)))
    (if (eq site *-nomis/ec-site*)
        ;; No need for a new overlay.
        (funcall f)
      (let* ((*-nomis/ec-site* site))
        (-nomis/ec-overlay-single-lump site *-nomis/ec-level* start end)
        (funcall f)))))

(cl-defmacro -nomis/ec-with-site ((site &optional end) &body body)
  (declare (indent 1))
  `(-nomis/ec-with-site* ,site ,end (lambda () ,@body)))

(defun -nomis/ec-overlay-args-of-form ()
  (save-excursion
    (down-list)
    (forward-sexp)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-walk-and-overlay)
      (forward-sexp))))

(defun -nomis/ec-overlay-site (site)
  (save-excursion
    (-nomis/ec-with-site (site)
      (-nomis/ec-overlay-args-of-form))))

(defun -nomis/ec-overlay-body (site)
  (save-excursion
    (when (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      ;; Whole body:
      (-nomis/ec-with-site (site
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

;;;; ___________________________________________________________________________
;;;; ---- Parse and overlay ----

(defun -nomis/ec-overlay-dom-xxxx ()
  (save-excursion
    (save-excursion (down-list)
                    (-nomis/ec-with-site (:client)
                      ;; Nothing more.
                      ))
    (-nomis/ec-overlay-args-of-form)))

(defun -nomis/ec-overlay-let (operator)
  (save-excursion
    (let* ((inherited-site *-nomis/ec-site*))
      ;; Whole form:
      (-nomis/ec-with-site (:neutral)
        ;; Bindings:
        (-nomis/ec-checking-movement (operator
                                      (down-list 2))
          (while (-nomis/ec-can-forward-sexp?)
            ;; Skip the LHS of the binding:
            (forward-sexp)
            ;; Walk the RHS of the binding, if there is one:
            (when (-nomis/ec-can-forward-sexp?)
              (-nomis/ec-bof)
              (-nomis/ec-with-site (inherited-site)
                (-nomis/ec-walk-and-overlay))
              (forward-sexp))))
        ;; Body:
        (backward-up-list)
        (forward-sexp)
        (-nomis/ec-overlay-body inherited-site)))))

(defun -nomis/ec-overlay-for-by (operator)
  (save-excursion
    (let* ((inherited-site *-nomis/ec-site*))
      ;; Whole form:
      (-nomis/ec-with-site (:neutral)
        ;; Key function:
        (-nomis/ec-checking-movement (operator
                                      (progn (down-list)
                                             (forward-sexp)))
          (when (-nomis/ec-can-forward-sexp?)
            (-nomis/ec-bof)
            (-nomis/ec-with-site (inherited-site)
              (-nomis/ec-walk-and-overlay))
            (forward-sexp)))
        ;; Bindings:
        (-nomis/ec-checking-movement (operator
                                      (down-list))
          (while (-nomis/ec-can-forward-sexp?)
            ;; Skip the LHS of the binding:
            (forward-sexp)
            ;; Walk the RHS of the binding, if there is one:
            (when (-nomis/ec-can-forward-sexp?)
              (-nomis/ec-bof)
              (-nomis/ec-with-site (inherited-site)
                (-nomis/ec-walk-and-overlay))
              (forward-sexp))))
        ;; Body:
        (backward-up-list)
        (forward-sexp)
        (-nomis/ec-overlay-body inherited-site)))))

(defun -nomis/ec-overlay-other-bracketed-form ()
  (save-excursion
    (down-list)
    (while (-nomis/ec-can-forward-sexp?)
      (-nomis/ec-bof)
      (-nomis/ec-walk-and-overlay)
      (forward-sexp))))

(defun -nomis/ec-operator-call-regexp (operator &optional no-symbol-end?)
  (concat "(\\([[:space:]]\\|\n\\)*"
          operator
          (if no-symbol-end? "" "\\_>")))

(defconst -nomis/ec-e/client-form-regexp (-nomis/ec-operator-call-regexp "e/client"))
(defconst -nomis/ec-e/server-form-regexp (-nomis/ec-operator-call-regexp "e/server"))
(defconst -nomis/ec-e/fn-form-regexp     (-nomis/ec-operator-call-regexp "e/fn"))
(defconst -nomis/ec-dom/-form-regexp     (-nomis/ec-operator-call-regexp "dom/" t))
(defconst -nomis/ec-let-form-regexp      (-nomis/ec-operator-call-regexp "let"))
(defconst -nomis/ec-binding-form-regexp  (-nomis/ec-operator-call-regexp "binding"))
(defconst -nomis/ec-e/for-form-regexp    (-nomis/ec-operator-call-regexp "e/for"))
(defconst -nomis/ec-e/for-by-form-regexp (-nomis/ec-operator-call-regexp "e/for-by"))

(defun -nomis/ec-walk-and-overlay ()
  (save-excursion
    (cl-ecase -nomis/ec-electric-version
      (:v2
       (cond
        ((looking-at -nomis/ec-e/client-form-regexp) (-nomis/ec-overlay-site :client))
        ((looking-at -nomis/ec-e/server-form-regexp) (-nomis/ec-overlay-site :server))
        ((-nomis/ec-looking-at-bracketed-sexp-start) (-nomis/ec-overlay-other-bracketed-form))))
      (:v3
       (cond
        ((looking-at -nomis/ec-e/client-form-regexp) (-nomis/ec-overlay-site :client))
        ((looking-at -nomis/ec-e/server-form-regexp) (-nomis/ec-overlay-site :server))
        ((looking-at -nomis/ec-e/fn-form-regexp)     (-nomis/ec-overlay-site :neutral))
        ((looking-at -nomis/ec-dom/-form-regexp)     (-nomis/ec-overlay-dom-xxxx))
        ((looking-at -nomis/ec-let-form-regexp)      (-nomis/ec-overlay-let "let"))
        ((looking-at -nomis/ec-binding-form-regexp)  (-nomis/ec-overlay-let "binding"))
        ((looking-at -nomis/ec-e/for-form-regexp)    (-nomis/ec-overlay-let "e/for"))
        ((looking-at -nomis/ec-e/for-by-form-regexp) (-nomis/ec-overlay-for-by "for-by"))
        ((-nomis/ec-looking-at-bracketed-sexp-start) (-nomis/ec-overlay-other-bracketed-form)))))))

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
  (unless -nomis/ec-electric-version
    (-nomis/ec-detect-electric-version))
  (let* ((*-nomis/ec-n-lumps-in-current-update* 0))
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
        ;; (nomis/ec-message-no-disp "*-nomis/ec-n-lumps-in-current-update* = %s"
        ;;                           *-nomis/ec-n-lumps-in-current-update*)
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
    (nomis/ec-message-no-disp "----------------")
    (dolist (ov ovs)
      (let* ((ov-start (overlay-start ov))
             (ov-end   (overlay-end ov))
             (end      (min ov-end
                            (save-excursion
                              (goto-char ov-start)
                              (pos-eol)))))
        (nomis/ec-message-no-disp "%s %s %s%s"
                                  (overlay-get ov 'priority)
                                  ov
                                  (buffer-substring ov-start end)
                                  (if (> ov-end end)
                                      "..."
                                    ""))))
    (message "No. of overlays = %s" (length ovs))))

;;;; ___________________________________________________________________________

(provide 'nomis-electric-clojure)
