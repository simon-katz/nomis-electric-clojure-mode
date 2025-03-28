# Changelog

## Version 0.5 — 2025-03-25

- Add support for multiple arities in `e/defn` and `e/fn`.

- Skip metadata.

- Don't site symbols that are Electric function names.

- Don't make locals in `binding`.

- Improve detection of Electric version — make it more lenient.

- Add dependency on the `dash` package.

- Breaking change: Change the extension mechanism.

  - (Note that the extension mechanism is alpha and subject to change.)

  - Change `:client`, `:server` and `:neutral` to `nec/client`, `nec/server` and `nec/neutral`.

  - Allow each term in a parser spec to specify a site, and remove the `apply-to` option.

  - Other changes that move knowledge away from the generic code and into the parser specs.

  - Change `:shape` to `:terms`.

  - Add `:ecase`, `:list` and `:+`.


## Version 0.4 — 2025-03-18

- Don't color Electric calls.

- Don't color bound symbols when used in certain contexts:
  - as an arg in an Electric call
  - as the RHS of a binding pair.

- Provide an extension mechanism so that you can teach the mode about user-land binding macros.

- Support destructuring in `let-bindings` forms and `fn-bindings` forms.

- Understand that functions can have doc strings and attr-maps.

- Understand that an `e/fn` can have a name.

- Add dependency on the `parseclj` package.


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
