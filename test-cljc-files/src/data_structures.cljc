(ns data-structures
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]
  {:a [global-1 local-1]
   :b #{global-1 local-1}
   :c (e/client global-1)
   :d (e/server local-1)
   (e/client :e) global-1
   (e/server :f) local-1
   :g {:h (e/client [global-1
                     #{local-1
                       (e/server
                        {:i (hosted-call global-1 local-1)
                         :j (ElectricCall global-1 local-1)})}])}})
