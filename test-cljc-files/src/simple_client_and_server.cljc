(ns simple-client-and-server
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]
  local-1
  global-1
  (hosted-call local-1 global-1)
  (ElectricCall local-1 global-1)
  (e/client local-1
            global-1
            (hosted-call local-1 global-1)
            (ElectricCall local-1 global-1))
  (e/server local-1
            global-1
            (hosted-call local-1 global-1)
            (ElectricCall local-1 global-1)))
