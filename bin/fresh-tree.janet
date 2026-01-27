(use /schema /environment)

(defn main
  "Make fresh store for the tree"
  [_ &opt fill-registrations]
  (def image ((=> :symbionts :tree :image) compile-config))
  (if (os/stat image)
    (os/rm image))
  (def store (:init (make Store :image image)))
  (:save store (parse (slurp "docs/init.jdn")))
  (if fill-registrations
    (each [hu fn ln dm]
      (fixtures 150
                ["Oxford" "YALE" "Cambridge" "CULS"]
                ["John" "Ringo" "George" "Joseph"]
                ["Smith" "Doe" "Grave" "Norman"]
                ["com" "eu" "cz"])
      (def em (string fn "." ln "@" hu "." dm))
      (def r {:email em
              :fullname (string fn " " ln)
              :home-university hu
              :faculty "FEM"})
      (:save store r :registrations (hash em))))
  (:flush store))
