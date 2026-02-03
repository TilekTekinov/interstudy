(use /environment /schema spork/sh-dsl)

(defn ^save-sha
  "Event that saves git sha"
  [sha]
  (make-update
    (fn [_ {:view view}] ((>put :sha sha) view))
    "save sha"))

(define-watch GitSHA
  "Save in the state the latest sha of the repository"
  [_ {:build-path bp}]
  (^save-sha
    (do
      ($ cd ,bp)
      (string ($<_ git rev-parse HEAD)))))

(define-event Released
  "Marks the end of releasing"
  {:update
   (fn [_ {:view view}]
     ((>put :releasing false) view))
   :watch [(^reconnect-peers (log "Released")) GitSHA]})

(define-effect StopPeers
  "Sends stop RPC to all peers"
  [_ state _]
  (each peer (state :peers)
    (:stop (state peer))))

(define-watch Release
  "Release producer"
  [_ {:dry dry :peers peers :build-path bp :release-path rp} _]
  (def jp (script "janet-pm"))
  (def out @"")
  (defn >out [& o] (buffer/push-string out ;o))
  (producer
    (produce (log "Starting new release"))
    (if dry
      (do
        (ev/sleep 0.1)
        (>out "Build dry run")
        (each peer peers (>out "Move " peer)))
      (do
        (>out ($<_ cd ,bp))
        (>out ($<_ git pull))
        (>out ($<_ . ./dev/bin/activate))
        (>out ($<_ ,jp "clean"))
        (>out ($<_ ,jp "build"))
        (produce StopPeers)
        (each peer peers
          (def p (string "_build/release/" peer))
          (>out ($<_ mv ,p ,rp))
          ($<_ nohup ,(string rp p) > /dev/null "2>&1" &))))
    (produce (log out) Released)))

(defn ^release
  "Event that release the new version of the thicket."
  [now]
  (make-event
    {:update
     (fn [_ {:view view}] ((>put :releasing now) view))
     :watch Release}
    "release"))

(define-event PrepareView
  "Prepares view"
  {:update (fn [_ state] (put state :view @{}))
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(def rpc-funcs
  "RPC functions for the tree"
  (merge-into
    @{:state
      (fn [&]
        (define :view)
        (if-let [releasing (view :releasing)]
          [:busy (view :releasing)]
          [:idle (view :sha)]))
      :release
      (fn [&]
        (define :view)
        (if-let [releasing (view :releasing)]
          [:busy releasing]
          (do
            (def now (os/clock))
            (produce (^release now))
            [:ok now])))}))

(def initial-state
  "Navigation to initial state in config"
  ((=> (=>symbiont-initial-state :demiurge)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(defn main
  ```
  Main entry into tree.
  ```
  [_]
  (->
    initial-state
    (make-manager on-error)
    (:transact PrepareView GitSHA RPC)
    (:transact (^connect-peers (log "Demiurge is ready")))
    :await)
  (os/exit 0))
