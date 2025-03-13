(ns electric-calls-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn platform-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(e/defn Foo [x y]
  (e/client
    (ElectricCall x
                  global-1
                  (platform-call x global-1)
                  (ElectricCall y
                                global-1
                                (platform-call x global-1))
                  (e/server (ElectricCall y
                                          global-1
                                          (platform-call x global-1))))))
