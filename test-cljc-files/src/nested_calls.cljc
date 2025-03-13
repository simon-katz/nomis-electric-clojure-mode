(ns nested-calls
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo []
  (let [local-1 1
        local-2 2]
    (ElectricCall global-1 local-2)
    (hosted-call global-1 local-2)
    (e/server
      (hosted-call global-1
                   local-1
                   (hosted-call global-1
                                local-1
                                (ElectricCall global-1
                                              local-1)
                                (hosted-call (hosted-call global-1
                                                          local-1)
                                             (ElectricCall global-1
                                                           local-1)))
                   (ElectricCall global-1
                                 local-1
                                 (ElectricCall global-1
                                               local-1)
                                 (hosted-call (hosted-call global-1
                                                           local-1)
                                              (ElectricCall global-1
                                                            local-1)))))))
