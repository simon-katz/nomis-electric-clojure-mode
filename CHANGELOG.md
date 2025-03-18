# Changelog

## Version 0.4 — 2025-03-18

- Don't color Electric calls.

- Don't color bound symbols when used in certain contexts:
  - as an arg in an Electric call
  - as the RHS of a binding pair.

- Provide an extension mechanism so that you can teach the mode about user-land binding macros.

- Support destructuring in `let-bindings` forms and `fn-bindings` forms.

- Understand that functions can have doc strings and attr-maps.

- Understand that an `e/fn` can have a name.


## Version 0.3 — 2025-03-12

- Add `nomis/ec-use-underline?`.
- Add `M-x nomis/ec-cycle-options` to cycle through combinations of `nomis/ec-color-initial-whitespace?` and `nomis/ec-use-underline?`.


## Version 0.2 — 2025-03-10 — Commit hash f79f10d

- Add `e/for` in v3.
- Add `e/for-by` in v3.
- Allow whitespace after the parenthesis when looking for operators.
  - For example, `( e/client ...)`.


## Version 0.1 – 2025-03-09

Initial version.
