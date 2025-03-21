(ns binding-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]
  (e/server
   (binding [local-2 global-1
             local-3 local-1
             local-4 local-2
             local-5 (ElectricCall global-1 local-2)
             local-6 (hosted-call global-1 local-2)]
     (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6)
     (hosted-call global-1 local-1 local-2 local-3 local-4 local-5 local-6)
     (e/client
      (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6)
      (hosted-call global-1 local-1 local-2 local-3 local-4 local-5 local-6)))
   ;; `local-2` etc are out of scope:
   (ElectricCall global-1 local-1 local-2 local-2 local-3 local-4 local-5 local-6)
   (hosted-call global-1 local-2 local-2 local-2 local-3 local-4 local-5 local-6)))
