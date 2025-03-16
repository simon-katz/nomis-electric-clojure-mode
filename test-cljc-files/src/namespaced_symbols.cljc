(ns namespaced-symbols
  (:require
   [hyperfiddle.electric3 :as e]
   [other-namespace-1]
   [Other-namespace-2]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(e/defn Foo [x]
  (e/server
   (hosted-call x)
   (ElectricCall x)
   (other-namespace-1/hosted-call x)
   (other-namespace-1/ElectricCall x)
   (Other-namespace-2/hosted-call x)
   (Other-namespace-2/ElectricCall x)))
