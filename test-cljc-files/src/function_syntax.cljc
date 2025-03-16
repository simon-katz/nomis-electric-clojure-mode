(ns function-syntax
  (:require
   [hyperfiddle.electric3 :as e]))

(e/defn Foo1 []
  42)

(e/defn Foo1
  "A doc string."
  []
  42)
