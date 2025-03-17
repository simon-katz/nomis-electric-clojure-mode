(ns e-fn-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]
  (e/server
    (let [F (e/fn [local-2 local-3]
              (ElectricCall global-1 local-1 local-2 local-3)
              (hosted-call global-1 local-1 local-2 local-3)
              (e/client
                (ElectricCall global-1 local-1 local-2 local-3)
                (hosted-call global-1 local-1 local-2 local-3))
              (e/server
                (ElectricCall global-1 local-1 local-2 local-3)
                (hosted-call global-1 local-1 local-2 local-3)))]
      (F local-1
         global-1)
      ;; `local-2` etc are out of scope:
      (ElectricCall global-1 local-1 local-2 local-3)
      (hosted-call global-1 local-1 local-2 local-3))))
