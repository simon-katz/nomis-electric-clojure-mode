(ns bindings
  (:require
   [hyperfiddle.electric3 :as e]))

(defn platform-call [& _])

(e/defn ElectricCall [& _])

(def global-1 42)

(e/defn Foo1 [local-1]
  (e/server
    (let [local-2             global-1
          [local-3 local-4]   [(ElectricCall global-1 local-2)
                               (platform-call global-1 local-2)]
          {:keys
           [local-5 local-6]} (e/client
                                [(ElectricCall global-1 local-2)
                                 (platform-call global-1 local-2)])]
      (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6)
      (platform-call global-1 local-1 local-2 local-3 local-4 local-5 local-6)
      (e/client
        (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6)
        (platform-call global-1 local-1 local-2 local-3 local-4 local-5 local-6))
      (e/server
        (ElectricCall global-1 local-1 local-2 local-3 local-4 local-5 local-6)
        (platform-call global-1 local-1 local-2 local-3 local-4 local-5 local-6))


      ;; TODO: This is wrong, right? Need to walk over the args.
      (platform-call (ElectricCall global-1 local-2))

      ;; TODO: What about `(e/fn ...)` in the function position?...
      ((e/fn [x y & _]
         (ElectricCall x y global-1 local-1 local-2 local-3)
         (platform-call x y global-1 local-1 local-2 local-3)
         (e/client
           (ElectricCall x y global-1 local-1 local-2 local-3)
           (platform-call x y global-1 local-1 local-2 local-3))
         (e/server
           (ElectricCall x y global-1 local-1 local-2 local-3)
           (platform-call x y global-1 local-1 local-2 local-3)))
       global-1
       ;; TODO: The following coloring is wrong.
       ;;       I think we need to recognise `((e/fn ...) ...)` as an Electric call.
       local-1
       (ElectricCall local-1)))))
