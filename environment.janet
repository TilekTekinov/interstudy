(import gp/environment/app :prefix "" :export true)

(defn =>machine-config
  "Navigation to extract `machine` congig from main config"
  [machine &opt suffix]
  (def c @[{:name (string machine ;(if suffix ["-" suffix] []))}])
  (=> (<- c (=> :deploy))
      (<- c (=> :machines machine))
      (<- c (=> :mycelium :nodes machine))
      (<- c (=> :mycelium (>select-keys :psk)))
      (>base c) (>merge)))

# Test helpers
(defmacro init-test
  "Initializes test defs and store"
  [&opt cookie?]
  (default cookie? true)
  (def now (- (os/time) 10))
  ~(upscope
     (def {:http http-url
           :image image
           :key key
           :rpc rpc-url
           :psk psk} ((=>machine-config :student) compile-config))
     (def image-file (string image ".jimage"))
     (if (os/stat image-file) (os/rm image-file))
     (def test-store (:init (make Store :image image)))
     (def cookie "f98bb104ad8468452201aaeab1410f12")
     (:save test-store (pwhash/create "s3ntr7" key) :secret)
     (:save test-store ,(if cookie? ~[cookie @{:logged ,now :active ,now}] '[]) :session)
     (:flush test-store)
     (defn url [path] (string "http://" http-url path))
     (defn auth-req
       [method path &named headers body urlenc]
       (default headers
         (if urlenc {"Content-Type" "application/x-www-form-urlencoded"} {}))
       (request (string/ascii-upper method) path
                :body body
                :headers (merge {"Cookie" (string "session=" cookie)}
                                headers)))))
