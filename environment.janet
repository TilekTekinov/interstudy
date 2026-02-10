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
           (=> (>sort-by (=> :score)) reverse))))

(def <:= ">collect-into alias" >collect-into)

(defn =>symbiont-initial-state
  "Navigation to extract `symbiont` congig from main config"
  [symbiont]
  (let [c @[{:name symbiont}]
        =>guards (=> :symbionts symbiont :guards)
        =>membrane (=> :membranes :nodes symbiont)
        =>neighbors (=> =>membrane :neighbors)
        =>mycelium-node |(=> :mycelium :nodes $)
        =>mycelium (=>mycelium-node symbiont)
        =>peers (=> =>mycelium :peers)]
    (=> (<- c (=> :name |{:thicket $}))
        (<- c (=> :deploy))
        (<- c (=> :symbionts symbiont))
        (>if (=> :symbionts symbiont :image)
             (<- c (=> :symbionts symbiont :image
                       |{:image (path/posix/join ((c 2) :data-path) $)})))
        (>if =>guards
             (=> (<- c =>guards)
                 (<- c (=> :membranes :nodes |(get $ (array/pop c))))
                 (<- c =>guards)
                 (<- c (=> :mycelium :nodes |(get $ (array/pop c))))))
        (<- c (=> :mycelium (>select-keys :psk)))
        (>if =>mycelium (<- c =>mycelium))
        (>if =>membrane
             (=> (<- c =>membrane)
                 (>if (=> =>neighbors present?)
                      (=> (<- c =>neighbors)
                          (<- c (=> :membranes :nodes
                                    |(tabseq [i :in (array/pop c)] i
                                       ((=> i :address) $))))))))
        (>if (=> =>peers present?)
             (=> (<- c (=> =>peers))
                 (<- c |(tabseq [i :in (array/pop c)]
                          i ((=> (=>mycelium-node i) :rpc) $)))))
        (>if (=> =>membrane :public)
             (<- c (=> =>membrane :public
                       |{:public (path/posix/join ((c 2) :build-path) $)})))
        (>if =>guards
             (=> (<- c =>guards)
                 (<- c (>if (=> :membranes :nodes |(get $ (last c)) :public)
                            (=> :membranes :nodes |(get $ (array/pop c)) :public
                                |{:public (path/posix/join ((c 2) :build-path) $)})))))
        (>if (=> :symbionts symbiont :image)
             (<- c (=> :symbionts symbiont :image
                       |{:image (path/posix/join ((c 2) :data-path) $)})))
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

(defn jdn/render
  "Renders Janet `item` into jdn"
  [item]
  (string/format "%j" item))

(def =>header-cookie
  "Navigate to cookie in request headers"
  (=> :headers "Cookie" "session"))

# HTTP
(defn ^write-spawn
  "Writes the spawn command to stdout"
  [peer arg]
  (make-effect
    (fn [_ {:dry dry} _]
      (unless dry
        (:write stdout (marshal [peer arg]))
        (:flush stdout)))
    "write spawn"))

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
(setdyn :ctx ctx)

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

(defn ^connect-peer
  "Connects to one peer"
  [peer]
  (make-event
    {:update
     (fn [_ state]
       (def {:psk psk :name name} state)
       (def url (state peer))
       (when (string? url)
         (def [host port] (server/host-port url))
         (put state peer
              (make rpc/Client
                    :host host :port port
                    :psk psk :name name))))
     :watch
     (fn [_ state _]
       (producer
         (var failed false)
         (var tries 0)
         (while
           (match [(protect (:open (state peer))) tries]
             [[true _] _] (produce (log "Connected to " peer))
             [[false _] 10] (produce (log "Cannot connect to " peer "."))
             true)
           (ev/sleep (* (++ tries) 0.1)))))}
    "connect peer"))

(defn ^connect-peers
  "Connects to all the peers"
  [succ &opt fail]
  (default fail succ)
  (make-event
    {:update
     (fn [_ state]
       (def {:psk psk :name name :peers peers} state)
       (each peer peers
         (def url (state peer))
         (unless (table? url)
           (def [host port] (server/host-port url))
           (put state peer
                (make rpc/Client
                      :host host :port port
                      :psk psk :name name)))))
     :watch
     (fn [_ state _]
       (producer
         (def {:peers peers} state)
         (var failed false)
         (each peer peers
           (var tries 0)
           (while
             (match [(protect (:open (state peer))) tries]
               [[true _] _] (produce (log "Connected to " peer))
               [[false _] 10] (do
                                (set failed true)
                                (produce (log "Cannot connect to " peer ".")))
               true)
             (ev/sleep (* (++ tries) 0.1))))
         (if failed (produce fail) (produce succ))))}
    "connect peers"))

(defn ^register
  "Registers for refresh"
  [peer]
  (make-watch
    (fn [_ state _]
      (:register (state peer) (state :name)))))

(define-watch ClosePeers
  "Closes all connections to peers"
  [_ state _]
  (def {:peers peers} state)
  (each peer peers (protect (:close (state peer)))))

(defn close-peers-stop
  "RPC function that closes peers and stops the server"
  [&]
  (produce ClosePeers
           (log "RPC server going down")
           Stop)
  :ok)

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
     (* (+ "admin" "student" "tree" "demiurge" "sentries"
           "bundle" "test" "schema" "environment" "dev")
        (thru ".janet") -1)
     (* "templates" (thru ".temple") -1)))

(defn shlc
  "Joins `parts` and make sh -lc"
  [& parts]
  [:sh "-lc" (string/join parts " ")])

(defn derive-from
  "Derives new key from master `key`"
  [key]
  (setdyn :ctx "intrstdy")
  (->> key
       (kdf/derive-from-key 16 (os/time) (dyn :ctx))
       util/bin2hex
       freeze))
