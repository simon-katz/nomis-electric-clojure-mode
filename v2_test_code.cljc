(ns v2-test-code
  (:require
   [hyperfiddle.electric-dom3 :as dom]
   [hyperfiddle.electric :as e]))

(defn bar [x & _] x)

(e/defn Foo1 []
  (+ 1 2 3)
  (e/client (bar 4 5 6))
  (e/server (map inc (range 10)))
  (dom/div 1 2 3)
  (e/server 1
            (e/client 2 (e/server 3))
            (bar (e/client 4)))
  (e/client (dom/div 1 2 3))
  (e/server (dom/div 1 2 3))
  (e/client (bar (e/fn []
                   (dom/div 1 2 3)
                   (bar 1 2 3 (dom/div 1 2 3))
                   (e/client 1
                             (e/server 2)
                             3))))
  (let [aaaa    (e/server 1 (e/client 2) 3)
        bbbbbbb (e/client 1 (e/server 2) 3)]
    (e/client aaaa
              (e/server bbbbbbb)
              (+ aaaa bbbbbbb 3 4)
              (dom/div (dom/text (str (e/server 3)))))
    (e/server aaaa
              bbbbbbb
              (let [a (do (bar 1) (bar 2) (e/client 3))
                    b (e/fn []
                        (+ 1
                           (e/client 2)
                           3))
                    c (+ a (e/call b))]
                (bar 1)
                (bar 2)
                (dom/div (str (e/client c)))))))

(e/defn Foo2 []
  (e/client 1
            (e/server 2)
            (e/fn [a b c] (+ a (e/client b) (e/server c)))
            3)
  (e/server 1
            (e/client 2)
            (e/fn [a b c] (+ a (e/client b) (e/server c)))
            3))
