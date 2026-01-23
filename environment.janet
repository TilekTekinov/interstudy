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

(defn =>course/by-code
  "Subject finder by code"
  [code]
  (=> :courses (>find-from-start (??? {:code (?eq code)}))))

# HTTP
(defmacro appcap
  "Convenience for app template capture"
  [title content]
  ~(app/capture :title ,title :content ,content))

(defn chunk-msg
  "Contructs chunk from msg"
  [msg]
  (string/format "%x\r\n%s\r\n" (length msg) msg))

(defn ds/patch-elements
  "Writes patch-elements SSE message to conn"
  [& elements]
  (def msg
    (chunk-msg
      (string
        "event: datastar-patch-elements\n"
        "data: elements " ;elements "\n\n")))
  (protect (:write (dyn :sse-conn) msg)))

(defmacro ds/element
  "Convenience to patch one element by selector"
  [sel & content]
  (assert ((??? string? (?find "#")) sel)
          "Selector must be css id selector with tag")
  (def [tag id] (string/split "#" sel))
  ~(,ds/patch-elements "<" ,tag " id='" ,id "'>" ,;content "</" ,tag ">"))

(defn ds/get
  "Constructs ds get uri"
  [& parts]
  (string "@get('" ;parts "')"))

# Utils
(def ctx
  "Jhydro context"
  "student0")

(defn hash
  "Returns hash item"
  [item]
  (and
    item
    (string (util/bin2hex (hash/hash 16 item ctx)))))

# Events
(define-event ConnectTree
  "Connects to the tree"
  {:update
   (fn [_ state]
     (def {:psk psk :name name :tree tree} state)
     (def [host port] (server/host-port tree))
     (put state :client
          (make rpc/Client
                :host host
                :port port
                :psk psk
                :name name)))
   :effect (fn [_ {:client client} _] (:open client))})

(define-effect CloseTree
  "Closes the tree client"
  [_ {:client client} _]
  (:close client))


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
     (def test-store
       (when image
         (def image-file (string image ".jimage"))
         (if (os/stat image-file) (os/rm image-file))
         (:init (make Store :image image))))
     (defn url [path] (string "http://" http-url path))))

(def test-data "Test data" (parse (slurp "test/data.jdn")))

(defmacro load-dump
  "Loads dump into test-store"
  [file]
  ~(do
     (:save test-store ,test-data)
     (:flush test-store)))
