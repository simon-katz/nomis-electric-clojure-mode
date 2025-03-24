(ns do-not-site-electric-fun-symbols
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [local-1]
  (e/server Foo
            (ElectricCall local-1
                          global-1
                          Foo
                          (ElectricCall Foo))
            (hosted-call local-1
                         global-1
                         Foo
                         (ElectricCall Foo)))
  (e/server e/Partial
            (ElectricCall local-1
                          global-1
                          Foo
                          (ElectricCall Foo))
            (hosted-call local-1
                         global-1
                         Foo
                         (ElectricCall Foo)))
  (binding [e/Tap-diffs (e/Partial e/Tap-diffs #(hosted-call %))]
    42))
