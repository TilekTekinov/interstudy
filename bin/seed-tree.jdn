(use /schema /environment)

(defn main
  "Make fresh store for the tree"
  [_ &opt fill-registrations]
  (def rng (math/rng (os/cryptorand 8)))
  (def image ((=> :symbionts :tree :image) compile-config))
  (if (os/stat image)
    (os/rm image))
  (def store (:init (make Store :image image)))
  (:save store (parse (slurp "seed.jdn")))
  (if fill-registrations
    (each [hu fn ln dm]
      (fixtures 50
                ["Oxford" "YALE" "Cambridge" "CULS"]
                ["John" "Ringo" "George" "Joseph" "Carlos"
                 "Jane" "Evelin" "Edith" "Sara" "Rachel" "Anna"]
                ["Smith" "Doe" "Grave" "Norman" "Trumpf" "White"
                 "Black" "Grey" "Anderson"]
                ["com" "eu" "cz" "ua"])
      (def em (string fn "." ln "@" hu "." dm))
      (def r ((>put :timestamp
                    (:epoch
                      (:sooner (dt/make-calendar (dt/now))
                               (dt/minutes (math/rng-int rng 90)))))
               @{:email em
                 :fullname (string fn " " ln)
                 :home-university hu
                 :faculty "FEM"}))
      (:save store r :registrations (hash em))))
  (:flush store))
