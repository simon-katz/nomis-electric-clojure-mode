(ns simple-client-and-server
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]

  global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1
  (hosted-call global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1)
  (ElectricCall global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1)
  (let [local-2 local-1]
    global-1 local-1 local-2 local-1 local-2 local-1 local-2)

  (e/client
    global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1
    (hosted-call global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1)
    (ElectricCall global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1)
    (let [local-2 local-1]
      global-1 local-1 local-2 local-1 local-2 local-1 local-2))

  (e/server
    global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1
    (hosted-call global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1)
    (ElectricCall global-1 global-1 global-1 local-1 local-1 local-1 global-1 local-1)
    (let [local-2 local-1]
      global-1 local-1 local-2 local-1 local-2 local-1 local-2)))
