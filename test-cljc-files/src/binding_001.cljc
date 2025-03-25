(ns binding-001
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(def ^:dynamic binding-1 1)
(def ^:dynamic EBinding1 1)

(e/defn Foo []
  (e/server
   ;; Note capitalized names and non-capitalized names are dealt
   ;; with differently.
   (binding [EBinding1 global-1
             binding-1 global-1]
     (ElectricCall global-1 EBinding1 binding-1)
     (hosted-call global-1 EBinding1 binding-1)
     (e/client
      (ElectricCall global-1 EBinding1 binding-1)
      (hosted-call global-1 EBinding1 binding-1)))))
