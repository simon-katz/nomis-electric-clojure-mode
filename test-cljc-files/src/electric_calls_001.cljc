(ns electric-calls-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo [x y]
  (e/client
    (ElectricCall x
                  global-1
                  (hosted-call x global-1)
                  (ElectricCall y
                                global-1
                                (hosted-call x global-1))
                  (e/server (ElectricCall y
                                          global-1
                                          (hosted-call x global-1))))))
