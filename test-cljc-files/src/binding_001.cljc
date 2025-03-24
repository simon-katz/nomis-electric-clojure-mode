(ns binding-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]
  (e/server
   (binding [b-2 global-1
             b-3 local-1
             b-4 b-2
             b-5 (ElectricCall global-1 b-2)
             b-6 (hosted-call global-1 b-2)]
     (ElectricCall global-1 local-1 b-2 b-3 b-4 b-5 b-6)
     (hosted-call global-1 local-1 b-2 b-3 b-4 b-5 b-6)
     (e/client
      (ElectricCall global-1 local-1 b-2 b-3 b-4 b-5 b-6)
      (hosted-call global-1 local-1 b-2 b-3 b-4 b-5 b-6)))))
