# Introduction

This is an Emacs minor mode for [Electric Clojure](https://github.com/hyperfiddle/electric). It colors client and server sites in source code.

Here's an example (code taken from [dir-tree example at Electric v3 tutorial](https://electric.hyperfiddle.net/tutorial/dir_tree)):

![dir-tree-example.png](docs/dir-tree-example.png)


# Installation

To install, copy the file `nomis-electric-clojure.el` to a place where it will be found by your Emacs and add the following to your init file:

```
  (require 'nomis-electric-clojure)
```

When you update `nomis-electric-clojure.el` to a new version, it is safest to restart Emacs rather than just evaluating the new code.


# How nomis-electric-clojure Recognises Electric Buffers

nomis-electric-clojure checks for Electric buffers by looking for one of the following near the start:

  - `[hyperfiddle.electric :as e]` (⇒ Electric v2)
  - `[hyperfiddle.electric3 :as e]` (⇒ Electric v3)

There's a customizable variable, `nomis/ec-bound-for-electric-require-search` (default 10000), that specifies how many characters into a buffer to search before giving up.


# Turning on nomis-electric-clojure-mode

By default, the mode is turned on automatically for any `.cljc` buffer that is recognised to be Electric source code. You can disable this by customizing `nomis/ec-auto-enable?`.

To turn the mode on or off manually, run `M-x nomis-electric-clojure-mode`. If the mode can't determine the Electric Version, it assumes v3.


# Overview of Features

nomis-electric-clojure-mode does the following:

- Auto-detects whether the code is Electric v2 or Electric v3. (If auto-detect fails, v3 is assumed.)

- Applies different colors to client regions and server regions.

- Does not apply a color to regions that may be either client or server.

The mode does not look at the call tree, so regions of code that are not colored may in fact always run on one site.


# Coloring Initial Whitespace

By default, initial whitespace is not colored.

You can change this by customizing `nomis/ec-color-initial-whitespace?` and you can toggle this on-the-fly with `M-x nomis/ec-toggle-color-initial-whitespace`.

Here's an example (code again taken from [dir-tree example at Electric v3 tutorial](https://electric.hyperfiddle.net/tutorial/dir_tree)):

![dir-tree-example-initial-whitespace.png](docs/dir-tree-example-initial-whitespace.png)


# FAQ

## nomis-electric-clojure-mode thinks code is v3 but actually it's v2, or vice versa

This can happen in a newly-created file or if the `:require` form in the namespace declaration is changed.

You can re-run the auto-detection of the version in any of the following ways:

- by running `M-x nomis/ec-redetect-electric-version`

- by turning the mode off and then back on (by running `M-x nomis-electric-clojure-mode` twice)

- by reverting the buffer.


# Remaining Work

For Electric v2 I don't think there's anything further to do.

I still need to finish going through the Electric v3 tutorial. I think I may want to add understanding of the contents of the `hyperfiddle.electric-forms3` namespace, or at least some of it. I'm not sure if there's anything else that could or should be done.


# Contributing

See [Contribution guidelines for this project](docs/CONTRIBUTING.md).
