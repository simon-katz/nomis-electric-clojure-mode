(ns let-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn platform-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

#_{:clj-kondo/ignore [:clojure-lsp/unused-public-var]}
(e/defn Foo [local-1]
  (e/server
    (let [local-2 global-1
          local-3 local-1
          local-4 local-2
          local-5 (ElectricCall global-1 local-2)
          local-6 (platform-call global-1 local-2)]
      (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6)
      (platform-call global-1 local-1 local-2 local-3 local-4 local-5 local-6))
    ;; `local-2` etc are  no longer local:
    (ElectricCall global-1 local-1 local-2 local-2 local-3 local-4 local-5 local-6)
    (platform-call global-1 local-2 local-2 local-2 local-3 local-4 local-5 local-6)))
