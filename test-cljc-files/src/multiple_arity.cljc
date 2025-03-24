(ns multiple-arity
  (:require
   [hyperfiddle.electric-dom3 :as dom]
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& args] (println args))

(e/defn ElectricCall [& args] (dom/div (dom/text (pr-str args))))

(def global-1 42)

(e/defn Foo1
  ([local-1]
   (e/server
     (ElectricCall local-1 global-1 (hosted-call local-1 global-1))))

  ([local-1 local-2]
   (e/client
     (ElectricCall local-1 global-1 (hosted-call local-2 global-1))))

  ([local-1 local-2 local-3]
   (+ local-1 local-2 local-3))

  ;; Ah, Electric Clojure doesn't support this (on 2025-03-24).
  {:an-attr-map true}
  )

(e/defn Foo2 garbage)

(e/defn Foo3)

(e/defn Main []
  (Foo1 100))
