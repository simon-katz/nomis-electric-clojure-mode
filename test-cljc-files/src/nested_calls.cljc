(ns nested-calls
  (:require
   [hyperfiddle.electric-dom3 :as dom]
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [x]
  (println "hosted-call" x)
  x)

(e/defn ElectricCall [x]
  (let [PrintInfo (e/fn [xx]
                    (dom/div (dom/text "ElectricCall " xx))
                    (println "ElectricCall" xx))]
    (PrintInfo x)
    (e/client (PrintInfo x))
    (e/server (PrintInfo x)))
  x)

(e/defn Main []
  (let [v 0]
    (hosted-call (let [v (inc v)]
                   (ElectricCall (hosted-call v)))))
  (let [v 10]
    (e/client
      (hosted-call (let [v (inc v)]
                     (ElectricCall (hosted-call v))))))
  (let [v 100]
    (e/server
      (hosted-call (let [v (inc v)]
                     (ElectricCall (hosted-call v)))))))
