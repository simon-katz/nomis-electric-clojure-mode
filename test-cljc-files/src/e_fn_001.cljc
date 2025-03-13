(ns e-fn-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn host-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(e/defn Foo [local-1]
  (e/server
    (let [F (e/fn [local-2 local-3]
              (ElectricCall global-1 local-1 local-2 local-3)
              (host-call global-1 local-1 local-2 local-3)
              (e/client
                (ElectricCall global-1 local-1 local-2 local-3)
                (host-call global-1 local-1 local-2 local-3))
              (e/server
                (ElectricCall global-1 local-1 local-2 local-3)
                (host-call global-1 local-1 local-2 local-3)))]
      (F local-1
         global-1)
      ;; `local-2` etc are no longer local:
      (ElectricCall global-1 local-1 local-2 local-3)
      (host-call global-1 local-1 local-2 local-3))))
