(ns classification-of-non-descended-forms
  (:require
   [hyperfiddle.electric3 :as e]))

(defn hosted-call [& _])

(e/defn ElectricCall [& _])

(e/defn ElectricCall2 [& _])

(def global-1 42)

(e/defn Foo [local-1]
  (e/server ElectricCall2
            hosted-call
            'foo
            '(foo foo)
            local-1
            global-1
            "a-string"
            123
            :foo
            (hosted-call ElectricCall2
                         hosted-call
                         'foo
                         '(foo foo)
                         local-1
                         global-1
                         "a-string"
                         123
                         :foo)
            (ElectricCall ElectricCall2
                          hosted-call
                          'foo
                          '(foo foo)
                          local-1
                          global-1
                          "a-string"
                          123
                          :foo)))
