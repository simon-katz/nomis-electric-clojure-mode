(ns for-by-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo1 [h]
  (e/server
    #_:clj-kondo/ignore
    (e/for-by hash [local-1 (.listFiles h)]
      (ElectricCall global-1 local-1)
      (hosted-call global-1 local-1))
    ;; `local-1` is out of scope:
    (ElectricCall global-1 local-1)
    (hosted-call global-1 local-1)))

(e/defn Foo2 [local-1 h]
  (e/server
    #_:clj-kondo/ignore
    (e/for-by hash [local-2 global-1
                    local-3 local-1
                    local-4 local-2
                    local-5 (ElectricCall local-2)
                    local-6 (hosted-call local-2)
                    local-7 (.listFiles h)]
      (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)
      (hosted-call global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)
      (e/client
        (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)
        (hosted-call global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)))
    ;; `local-2` etc are out of scope:
    (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)
    (hosted-call global-1 local-1 local-2 local-3 local-4 local-5 local-6 local-7)))
