(use /schema /environment)

(defn main
  "Make fresh store for the tree"
  [&]
  (def image ((=> :symbionts :tree :image) compile-config))
  (if (os/stat image)
    (os/rm image))
  (def store (:init (make Store :image image)))
  (:save store (parse (slurp "docs/dump.jdn")))
  (:flush store))
