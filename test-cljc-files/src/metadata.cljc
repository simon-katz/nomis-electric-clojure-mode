(ns metadata
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn ^:metadata-1 ^{:metadata-2 2} Foo1
  ^[:metadata-3] [local-1]
  (e/server
    (ElectricCall global-1 local-1)))
