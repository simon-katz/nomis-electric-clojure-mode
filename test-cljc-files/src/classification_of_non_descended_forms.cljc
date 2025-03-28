(ns classification-of-non-descended-forms
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(e/defn ElectricCall2 [& _])

(def global-1 42)

(e/defn Foo [local-1]
  (e/server "a-string"
            123
            :foo
            'foo
            '(foo foo)
            hosted-call
            ElectricCall2
            local-1
            global-1
            (hosted-call "a-string"
                         123
                         :foo
                         'foo
                         '(foo foo)
                         hosted-call
                         ElectricCall2
                         local-1
                         global-1)
            (ElectricCall "a-string"
                          123
                          :foo
                          'foo
                          '(foo foo)
                          hosted-call
                          ElectricCall2
                          local-1
                          global-1)))
