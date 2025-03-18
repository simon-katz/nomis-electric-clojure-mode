(ns function-syntax
  (:require
   [hyperfiddle.electric-dom3 :as dom]
   [hyperfiddle.electric3 :as e]))

(e/defn Foo1 []
  42)

(e/defn Foo2
  "A doc string." ; <-- doc string
  []
  42)

(e/defn Foo3 {:some-metadata 42} [xs] ; <-- attr-map
  (e/server
    (let [F (e/fn MyName [[x & xs]] ; <-- function name
              (when x
                (dom/div (dom/text x))
                (MyName xs)))]
      (F xs))))
