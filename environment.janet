(import gp/environment/app :prefix "" :export true)
(import /templates/app)

# Navigation
# TODO move to data/navigation
(defn >collect-at
  "Collects result of calling `fun` into `tbl` under `key`."
  [tbl key &opt fun]
  (fn >collect-at [base]
    (put tbl key (if fun (fun base) base))
    base))

(def <:- ">collect-at alias" >collect-at)

(defn >collect-into
  "Merges the result of running `fun` into the `tbl`"
  [tbl &opt fun]
  (fn >collect-merge [base]
    (merge-into tbl (if fun (fun base) base))
    base))

# TODO PR spork
(defn select-keys
  "Returns new table with selected `keyz` from dictionary `data`."
  [data keyz]
  (def res @{})
  (loop [k :in keyz :unless (nil? (data k))]
    (put res k (data k)))
  res)

(defn >select-keys
  ```
  Returns a function which selects `keys` from the base 
  and returns new table just with them.
  ```
  [& keys]
  (fn >select [i] (select-keys i keys)))

(defn enrich-fuzzy
  "Navigation that enriches item with fuzzy score."
  [search & fields]
  (fn [i]
    (def hay (string ;(seq [f :in fields] (get i f))))
    (merge i {:score (fuzzy/score search hay)})))

(def =>filter-sort-score
  "Navigation that filters score and sorts it"
  (=> (>Y (=> :score (?gt math/-inf)))
      (>if (??? {length (?lt 11)})
           (=> (>sort-by :score) reverse))))

(def <:= ">collect-into alias" >collect-into)

(defn =>symbiont-initial-state
  "Navigation to extract `symbiont` congig from main config"
  [symbiont]
  (let [c @[{:name (string symbiont)}]
        =>membrane (=> :membranes :nodes symbiont)
        =>neighbors (=> =>membrane :neighbors)
        =>mycelium-node |(=> :mycelium :nodes $)
        =>mycelium (=>mycelium-node symbiont)
        =>peers (=> =>mycelium :peers)]
    (=> (<- c (=> :name |{:thicket $}))
        (<- c (=> :deploy))
        (<- c (=> :symbionts symbiont))
        (>if =>membrane
             (=> (<- c =>membrane)
                 (>if (=> =>neighbors present?)
                      (=> (<- c =>neighbors)
                          (<- c (=> :membranes :nodes
                                    |(tabseq [i :in (array/pop c)] i
                                       ((=> i :address) $))))))))
        (<- c (=> :mycelium (>select-keys :psk)))
        (>if =>mycelium (<- c =>mycelium))
        (>if (=> =>peers present?)
             (=> (<- c (=> =>peers))
                 (<- c |(tabseq [i :in (array/pop c)]
                          i ((=> (=>mycelium-node i) :rpc) $)))))
        (>if (=> =>membrane :rpc) (<- c =>membrane))
        (>base c) (>merge))))

(defn update-rpc
  "Prepares RPC configuration"
  [funcs]
  (fn [url] @{:url url :functions funcs}))

(defn =>course/by-code
  "Subject finder by code"
  [code]
  (=> :courses (>find-from-start (??? {:code (?eq code)}))))

(def >stamp
  "Function that timestamps"
  (>put :timestamp (os/time)))

# HTTP
(defn appcap
  "Middleware for app template capture"
  [next-middleware]
  (fn :appcap [req]
    (if-let [resp (next-middleware req)
             [title content] resp]
      (http/html-success-resp
        (app/capture :title title :content content))
      (http/not-found))))

(defn chunk-msg
  "Contructs chunk from msg"
  [msg]
  (string/format "%x\r\n%s\r\n" (length msg) msg))

(defn ds/patch-elements
  "Writes patch-elements SSE message to conn"
  [elements &opt selector mode]
  (def msg
    (chunk-msg
      (string
        "event: datastar-patch-elements\n"
        (if selector (string "data: selector " selector "\n"))
        (if mode (string "data: mode " mode "\n"))
        "data: elements " elements "\n\n")))
  (protect (:write (dyn :sse-conn) msg)))

(defn ds/get
  "Constructs ds get uri"
  [& parts]
  (string "@get('" ;parts "')"))

(defn ds/post
  "Constructs ds post uri"
  [& parts]
  (string "@post('" ;parts "')"))

(defn ds/hg-stream
  "Convenience for defining SSE stream handler"
  [elements &opt selector mode]
  (http/stream (ds/patch-elements (hg/html elements) selector mode)))

(defn ds/input
  "Datastar input helper"
  [name & attrs]
  [:input (struct ;attrs :data-bind name)])

(defn ds/select
  "Datastar select helper"
  [name options]
  [:select {:data-bind name} options])

# Utils
(def ctx "Jhydro context" "interstu")

(defn hash
  "Returns hash item"
  [item]
  (and
    item
    (string (util/bin2hex (hash/hash 16 item ctx)))))

# Events
(defn ^refresh-view
  "Refreshes the data in view from tree"
  [& colls]
  (make-update
    (fn [_ state]
      (def {:tree tree :view view} state)
      (each coll colls
        (put view coll (coll tree))))))

(defn ^connect-peers
  "Connects to the tree"
  [& succ]
  (make-event
    {:update
     (fn [_ state]
       (def {:psk psk :name name :peers peers} state)
       (each peer peers
         (let [url (state peer)
               [host port] (server/host-port url)]
           (put state peer
                (make rpc/Client
                      :host host :port port
                      :psk psk :name name)))))
     :watch
     (fn [_ state _]
       (producer
         (def {:peers peers} state)
         (def res (array/new (length peers)))
         (each peer peers
           (var tries 0)
           (while (not ((protect (:open (state peer))) 0))
             (if (< tries 10)
               (++ tries)
               (do
                 (array/push res
                             (log "Cannot connect to " peer ". Exiting.") Stop)
                 (break)))
             (ev/sleep (* tries 0.1)))
           (array/push res (log "Connected to " peer)))
         (produce ;res ;succ)))}
    "connect peers"))

(defn ^reconnect-peers
  "Connects to the tree"
  [& succ]
  (make-watch
    (fn [_ state _]
      (producer
        (def {:peers peers} state)
        (def res (array/new (length peers)))
        (each peer peers
          (var tries 0)
          (while (not ((protect (:open (state peer))) 0))
            (if (< tries 10)
              (++ tries)
              (do
                (array/push res
                            (log "Cannot connect to " peer ". Exiting.") Stop)
                (break)))
            (ev/sleep (* tries 0.1)))
          (array/push res (log "Connected to " peer)))
        (produce ;res ;succ)))))

(defn ^delay
  "Delay the `event` for `s` time"
  [s event]
  (make-watch (producer (ev/sleep s) (produce event)) "delay"))

# Test helpers
(defmacro init-test
  "Initializes test defs and store"
  [symbiont]
  (def now (- (os/time) 10))
  (def store-name (symbol symbiont "-store"))
  ~(upscope
     (def {:http http-url
           :image image
           :key key
           :rpc rpc-url
           :psk psk} ((=>symbiont-initial-state ,symbiont) compile-config))
     (def test-store
       (when image
         (def image-file (string image ".jimage"))
         (if (os/stat image-file) (os/rm image-file))
         (:init (make Store :image image))))
     (defn url [path] (string "http://" http-url path))))

(def test-seed "Test seed" (parse (slurp "test/seed.jdn")))

(defmacro load-dump
  "Loads dump into test-store"
  [file]
  ~(do
     (:save test-store ,test-seed)
     (:flush test-store)))

(defn fixtures
  "Combine members of the `sets` to get `n` uniq combinations"
  [n & sets]
  (def rng (math/rng (os/cryptorand 8)))
  (def res @{})
  (while (< (length res) n)
    (put res
         (freeze
           (seq [set :in sets :let [ls (length set)]]
             (get set (math/rng-int rng ls))))
         true))
  (keys res))

# Bin helpers
(def project-files-peg
  "PEG for filewatch"
  '(+
     (* (+ "admin" "student" "tree" "demiurge"
           "bundle" "test" "schema" "environment" "dev")
        (thru ".janet") -1)
     (* "templates" (thru ".temple") -1)))
