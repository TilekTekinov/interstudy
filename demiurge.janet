(use /environment /schema spork/sh-dsl spork/sh)

(defn ^save-sha
  "Event that saves git sha"
  [sha]
  (make-update
    (fn [_ {:view view :release-path rp}]
      (def rsha (string (slurp (path/abspath (path/join rp "released.sha")))))
      ((=> (>put :sha sha) (>put :release-sha rsha)) view))
    "save sha"))

(define-effect GitPull
  "Pulls the latest from the origin"
  [&]
  ($< git pull))

(define-watch GitSHA
  "Save in the state the latest shas of the repository"
  [&]
  [GitPull (^save-sha (string ($<_ git rev-parse HEAD)))])

(define-event Released
  "Marks the end of releasing"
  {:update
   (fn [_ {:view view}] ((>put :releasing false) view))
   :watch [GitSHA]})

(defn ^stop-peer
  "Stops one peer"
  [peer]
  (make-effect
    (fn [_ state _]
      (def {:view {:spawned spawned}} state)
      (protect (:stop (state peer)))
      (protect (os/proc-kill (spawned peer))))))

# TODO seq
(define-event StopPeers
  "Sends stop RPC to all peers"
  {:update (fn [_ {:view view}] (put view :ran false))
   :watch (fn [_ state _]
            (def {:dry dry :peers peers :view {:spawned spawned}} state)
            (if (and spawned (not dry))
              (seq [peer :in peers] (^stop-peer peer))))})

(defn ^save-spawned
  "Saves peer's process"
  [peer proc]
  (make-update
    (fn [_ {:view {:spawned spawned}}]
      (put spawned peer proc))
    "save peer"))

(define-event RunPeers
  "Runs peers event"
  {:update
   (fn [_ {:view view}]
     (put view :ran (os/clock)))
   :watch
   (fn [_ {:dry dry :peers peers :release-path rp} _]
     (if-not dry
       (seq [peer :in peers]
         (^save-spawned
           peer (os/spawn [(path/join rp (executable peer))])))))})

(define-effect ReleaseSHA
  "Writes the current SHA to file"
  [_ {:view {:sha sha} :release-path rp} _]
  (spit (path/abspath (path/join rp "released.sha")) sha))

(defn ^deploy-peer
  "Deploys one peer"
  [peer]
  (make-event
    {:watch (log "Deploying peer " peer)
     :effect (fn [_ {:build-path bp :release-path rp} _]
               (def ep (executable peer))
               (copy-file
                 (path/abspath (path/join bp "_build/release/" ep))
                 (path/abspath (path/join rp ep))))}))

(define-watch Deploy
  "Deploys peers"
  [_ {:peers peers} _]
  [;(seq [peer :in peers]
      [(^stop-peer peer) (^deploy-peer peer)]) ReleaseSHA])

(define-event Build
  "Builds peers"
  {:effect
   (fn [_ {:view {:sha sha}} _]
     (def jp (script "janet-pm"))
     (protect ($<_ . ./dev/bin/activate))
     ($ ,jp "clean")
     ($ ,jp "build"))})

(defn ^release
  "Event that releases the new version of the thicket."
  [now]
  (make-event
    {:update
     (fn [_ {:view view}] ((>put :releasing now) view))
     :watch
     (fn [_ {:release-path rp :dry dry :peers peers :view {:sha sha :release-sha rsha}} _]
       (if (= sha rsha)
         (log "Latest version is already released")
         [(log "Starting new release")
          GitPull
          ;(if dry
             [(log "Build dry run")
              ;(seq [p :in peers] (log "Move " p))]
             [Build Deploy RunPeers Released])
          (log "Release finished")]))}
    "release"))

(define-event PrepareView
  "Prepares view"
  {:update (fn [_ state] (put state :view @{:spawned @{}}))
   :effect (fn [_ {:view view :build-path bp} _]
             (os/cd bp)
             (setdyn :view view))})

(def rpc-funcs
  "RPC functions for the tree"
  (merge-into
    @{:stop
      (fn [&]
        (define :view)
        (if-let [ts (view :ran)]
          (produce StopPeers))
        (produce (log "Demiurge going down") (^delay 0.001 Stop))
        :ok)
      :state
      (fn [&]
        (define :view)
        (if-let [releasing (view :releasing)]
          [:busy (view :releasing)]
          (if-let [ran (view :ran)]
            [:running ran]
            [:idle (view :sha)])))
      :release
      (fn [&]
        (define :view)
        (if-let [releasing (view :releasing)]
          [:busy releasing]
          (do
            (def now (os/clock))
            (produce (^release now))
            [:ok now])))
      :stop-all
      (fn [&]
        (define :view)
        (if-let [ts (view :ran)]
          (do (produce StopPeers) :ok)
          :not-running))
      :run-all
      (fn [&]
        (define :view)
        (if-let [ts (view :ran)]
          [:running ts]
          (do
            (produce RunPeers) :ok)))}))

(def initial-state
  "Navigation to initial state in config"
  ((=> (=>symbiont-initial-state :demiurge)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(define-watch Start
  "Tries to release and presents demiurge"
  [&] [(^release (os/clock)) (log "Demiurge is ready")])

(defn main
  ```
  Main entry into demiurge.
  ```
  [_]
  (->
    initial-state
    (make-manager on-error)
    (:transact GitSHA PrepareView RunPeers RPC)
    (:transact (^connect-peers Start))
    :await)
  (os/exit 0))
