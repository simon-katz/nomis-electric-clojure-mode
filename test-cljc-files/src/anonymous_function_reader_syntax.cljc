(ns anonymous-function-reader-syntax
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]
  (e/server
   (let [local-2 global-1
         f       #(hosted-call local-2 %1)]
      (f local-1))))
