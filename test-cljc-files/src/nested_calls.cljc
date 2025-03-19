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

(e/defn Main* [a b c d e f]
  (hosted-call (ElectricCall (hosted-call a)))
  (e/client (hosted-call (ElectricCall (hosted-call b))))
  (e/server (hosted-call (ElectricCall (hosted-call c))))
  ;;
  (ElectricCall (hosted-call (ElectricCall d)))
  (e/client (ElectricCall (hosted-call (ElectricCall e))))
  (e/server (ElectricCall (hosted-call (ElectricCall f)))))

(e/defn Main []
  (Main* 1 2 3 4 5 6))
