(ns metadata
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn ^:metadata-1 ^{:metadata-2 2} Foo1
  ^[:metadata-3] [local-1 local-2]
  (e/server
    (ElectricCall global-1 local-1)
    (let [^:metadata-4 local-3 ^:metadata-5 (hosted-call)]
      (println local-1)
      (println local-2)
      (println local-3))))
