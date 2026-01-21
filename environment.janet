(import gp/environment/app :prefix "" :export true)

# Navigation
(defn =>machine-initial-state
  "Navigation to extract `machine` congig from main config"
  [machine &opt tree]
  (let [c @[{:name (string machine)}]]
    (=> (<- c (=> :name |{:thicket $}))
        (<- c (=> :deploy))
        (<- c (=> :machines machine))
        (<- c (=> :mycelium (>select-keys :psk)))
        (>if (=> :mycelium :nodes machine)
             (<- c (=> :mycelium :nodes machine)))
        (>if (=> :membranes :nodes machine)
             (<- c (=> :membranes :nodes machine)))
        (>if (always tree)
             (<- c (=> :mycelium :nodes :tree :rpc |{:tree $})))
        (>base c) (>merge))))

(defn update-rpc
  "Prepares RPC configuration"
  [funcs]
  (fn [url] @{:url url :functions funcs}))

(defmacro appcap
  "Convenience for app template capture"
  [title content]
  ~(app/capture :title ,title :content ,content))

# Test helpers
(defmacro init-test
  "Initializes test defs and store"
  [machine]
  (def now (- (os/time) 10))
  (def store-name (symbol machine "-store"))
  ~(upscope
     (def {:http http-url
           :image image
           :key key
           :rpc rpc-url
           :psk psk} ((=>machine-initial-state ,machine) compile-config))
     (def image-file (string image ".jimage"))
     (if (os/stat image-file) (os/rm image-file))
     (def test-store (:init (make Store :image image)))
     (defn url [path] (string "http://" http-url path))))

(defmacro load-dump
  "Loads dump into test-store"
  [file]
  (def data (parse (slurp "test/data.jdn")))
  ~(upscope
     (:save test-store ,data)
     (:flush test-store)))
