(import gp/environment/app :prefix "" :export true)

(defn =>machine-initial-state
  "Navigation to extract `machine` congig from main config"
  [machine]
  (let [c @[@{:name (string machine)}]]
    (=> (<- c (=> :name |{:thicket $}))
        (<- c (=> :deploy))
        (<- c (=> :machines machine))
        (<- c (=> :mycelium :nodes machine))
        (<- c (=> :mycelium (>select-keys :psk)))
        (>base c) (>merge))))

(defn update-rpc
  "Prepares RPC configuration"
  [funcs]
  (fn [url] @{:url url :functions funcs}))

# Test helpers
(defmacro init-test
  "Initializes test defs and store"
  [machine &opt cookie?]
  (default cookie? true)
  (def now (- (os/time) 10))
  ~(upscope
     (def {:http http-url
           :image image
           :key key
           :rpc rpc-url
           :psk psk} ((=>machine-initial-state ,machine) compile-config))
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
