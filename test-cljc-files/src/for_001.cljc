(ns for-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo1 [local-1]
  (e/server
    (e/for [local-2 (e/diff-by hash (hosted-call local-1))]
      (ElectricCall global-1 local-2)
      (hosted-call global-1 local-2))))

(e/defn Foo2 [local-1]
  (e/server
    (e/for [local-2 (e/diff-by (e/fn [local-n]
                                 (e/server (ElectricCall local-1 local-n global-1)))
                               (hosted-call local-1))]
      (ElectricCall global-1 local-2)
      (hosted-call global-1 local-2))))

(e/defn Foo3 [local-1]
  (e/server
    (e/for [local-2 global-1
            local-3 local-1
            local-4 local-2
            local-5 (ElectricCall local-1)
            local-6 (hosted-call local-1)
            local-7 (e/diff-by hash (.listFiles h))]
      (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)
      (hosted-call global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)
      (e/client
        (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)
        (hosted-call global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)))))
