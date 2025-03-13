(ns hosted-lambdas-in-fun-position
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo1 [local-1]
  ((fn [local-2 local-3]
     (ElectricCall global-1 local-1 local-2 local-3)
     (hosted-call global-1 local-1 local-2 local-3)
     (e/client
       (ElectricCall global-1 local-1 local-2 local-3)
       (hosted-call global-1 local-1 local-2 local-3))
     (e/server
       (ElectricCall global-1 local-1 local-2 local-3)
       (hosted-call global-1 local-1 local-2 local-3)))
   global-1
   local-1))

(e/defn Foo2 [local-1]
  (e/client
    ((fn [local-2 local-3]
       (ElectricCall global-1 local-1 local-2 local-3)
       (hosted-call global-1 local-1 local-2 local-3)
       (e/client
         (ElectricCall global-1 local-1 local-2 local-3)
         (hosted-call global-1 local-1 local-2 local-3))
       (e/server
         (ElectricCall global-1 local-1 local-2 local-3)
         (hosted-call global-1 local-1 local-2 local-3)))
     global-1
     local-1)))

(e/defn Foo3 [local-1]
  ((e/client
     (fn [local-2 local-3]
       (ElectricCall global-1 local-1 local-2 local-3)
       (hosted-call global-1 local-1 local-2 local-3)
       (e/client
         (ElectricCall global-1 local-1 local-2 local-3)
         (hosted-call global-1 local-1 local-2 local-3))
       (e/server
         (ElectricCall global-1 local-1 local-2 local-3)
         (hosted-call global-1 local-1 local-2 local-3))))
   global-1
   local-1))
