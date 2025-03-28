(ns hosted-anonymous-functions
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

;; TODO: Rename -- not just reader syntax.
(e/defn Foo [local-1]
  (e/server
   (let [local-2 global-1
         f1      (fn [x y] (hosted-call x y local-2 global-1))
         f2      #(hosted-call %1 %2 local-2 global-1)]
     (f1 local-1 local-2)
     (f2 local-1 local-2)
     ((fn [x y] (hosted-call x y local-2 global-1))
      local-2
      global-1)
     (#(hosted-call %1 %2 local-2 global-1)
      local-2
      global-1))))
