(use spork/misc gp/data/store)

(defmacro reimport []
  '(upscope
     (import /environment :prefix "" :fresh true :export true)
     (import /schema :prefix "" :fresh true :export true)))

(reimport)


(defmacro reload []
  '(upscope
     (def tree-store (make Store :image ((=> :machines :tree :image) compile-config)))
     (:init tree-store)
     (def student-store (make Store :image ((=> :machines :student :image) compile-config)))
     (:init student-store)))

(reload)

