(ns destructuring
  (:require
   [hyperfiddle.electric3 :as e]
   [other-namespace]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo []
  (e/server
    (let [;; Vector destructuring:
          [x101
           x102
           & x103
           :as x104] (hosted-call global-1)

          ;; Map destructuring:
          {x201 :a
           x202 :b
           :x203 :c
           :keys [x204 :x205]
           :as x206} (ElectricCall global-1)

          ;; Nested:
          [[x301 x302]
           [x303 x304 & x305 :as x306]] (hosted-call global-1)

          {{:keys [x401 x402]} :k} (ElectricCall global-1)

          ;; Namespaced keywords:
          {:keys [:other-namespace/x501
                  other-namespace/x502]
           :other-namespace/keys [x503 x504]} (hosted-call global-1)

          ;; Auto-resolved keywords:
          {:keys [::other-namespace/x505
                  ::other-namespace/x506]} (ElectricCall global-1)]

      (ElectricCall global-1
                    x101 x102 x103 x104
                    x201 x202 x203 x204 x205 x206
                    x301 x302 x303 x304 x305 x306
                    x401 x402
                    x501 x502 x503 x504 x505 x506))))
