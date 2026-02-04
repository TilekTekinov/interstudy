(use /environment /schema spork/sh-dsl spork/sh)

(defn ^save-sha
  "Event that saves git sha"
  [sha]
  (make-update
    (fn [_ {:view view}]
      ((>put :sha sha) view))
    "save sha"))


# (def rshap (path/abspath (path/join rp "released.sha")))
# (def rsha (if (os/stat rshap) (string (slurp rshap))))
(define-effect SetReleasedSHA
  "Writes the current SHA to file"
  [_ {:view {:sha sha} :release-path rp} _]
  (spit (path/abspath (path/join rp "released.sha")) sha))

(define-watch GetGitSHA
  "Save in the state the latest shas of the repository"
  [_ {:release-path rp} _]
  (producer
    ($< git pull)
    (produce (^save-sha (string ($<_ git rev-parse HEAD))))))

(define-event Released
  "Marks the end of releasing"
  {:update
   (fn [_ {:view view}] ((>put :releasing false) view))
   :watch [GetGitSHA]})

(defn ^remove-peer
  "Removes peer from spawned"
  [peer]
  (make-update
    (fn [_ state]
      (def {:view {:spawned spawned}} state)
      (when (spawned peer)
        (def ep (state peer))
        (put state peer (string (ep :host) ":" (ep :port)))
        (put spawned peer nil)))))

(defn ^stop-peer
  "Stops one peer"
  [peer]
  (make-event
    {:watch (^remove-peer peer)
     :effect
     (fn [_ state _]
       (def {:view {:spawned spawned}} state)
       (def pc (state peer))
       (protect (:stop pc)
                (:close pc)
                (os/proc-kill (spawned peer))))}))

(define-event StopPeers
  "Sends stop RPC to all peers"
  {:update (fn [_ {:view view}] (put view :ran false))
   :watch
   (fn [_ state _]
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
   (fn [_ {:view view}] (put view :ran (os/clock)))
   :watch
   (fn [_ {:dry dry :peers peers :release-path rp} _]
     (if-not dry
       (seq [peer :in peers
             :let [ep (path/join rp (executable peer))]
             :when (os/stat ep)]
         (^save-spawned peer (os/spawn [ep])))))})

(defn ^deploy-peer
  "Deploys one peer"
  [peer]
  (make-event
    {:watch (log "Deployed peer " peer)
     :effect (fn [_ {:build-path bp :release-path rp} _]
               (def ep (executable peer))
               (def target (path/abspath (path/join rp ep)))
               (protect (os/rm target))
               (copy-file
                 (path/abspath (path/join bp "_build/release/" ep))
                 target))}))

(define-watch Deploy
  "Deploys peers"
  [_ {:peers peers} _]
  [;(seq [peer :in peers] (^deploy-peer peer))])

(define-event Build
  "Builds peers"
  {:effect
   (fn [_ {:view {:sha sha}} _]
     (def jp (script "janet-pm"))
     (def ap "./prod/bin/activate")
     ($ ls -la ,ap)
     ($ . ,ap)
     ($ ,jp "clean")
     ($ ,jp "build"))})

(defn ^release
  "Event that releases the new version of the thicket."
  [now]
  (make-event
    {:update
     (fn [_ {:view view}] ((>put :releasing now) view))
     :watch
     (fn [_ {:release-path rp :dry dry
             :view {:sha sha :release-sha rsha}} _]
       (if (and rsha (= sha rsha))
         [(log "Latest version is already released") Released]
         [(log "Starting new release")
          ;(if dry
             [(log "Build dry run") (^delay 0.001 Released)]
             [GetGitSHA StopPeers Build Deploy
              SetReleasedSHA Released RunPeers])
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
            (produce RunPeers (^connect-peers (log "Demiurg is ready"))) :ok)))}))

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
    (:transact RPC GetGitSHA PrepareView RunPeers)
    (:transact (^connect-peers Start))
    :await)
  (os/exit 0))
