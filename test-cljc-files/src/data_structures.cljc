(ns data-structures
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo1 []

  [:a (e/client :b) (e/server :c)]

  {:a (e/client 1)
   :b (e/server 2)
   (e/client :c) 3
   (e/server :d) 4}

  #{:a (e/client :b) (e/server :c)})


(e/defn Foo2 []
  (let [local-1 1
        local-2 2]

    (hosted-call [[local-1 local-2]
                  {:a local-1
                   :b local-2}
                  #{local-1 local-2}])


    (e/client [local-1 local-2]
              {:a local-1
               :b local-2}
              #{local-1 local-2})

    (hosted-call global-1 [local-1 local-2])

    (ElectricCall [local-1 local-2]
                  {:a local-1
                   :b local-2}
                  #{local-1 local-2})

    (e/client
      (ElectricCall [local-1 local-2]
                    {:a local-1
                     :b local-2}
                    #{local-1 local-2}))))
