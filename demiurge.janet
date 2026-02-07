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
                (os/proc-wait (spawned peer))))}))

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
                 target)
               (os/chmod target 8r700))}))

(define-watch Deploy
  "Deploys peers"
  [_ {:peers peers} _]
  [;(seq [peer :in peers] (^deploy-peer peer))])

(define-event Build
  "Builds peers"
  {:effect
   (fn [_ {:view {:sha sha}} _]
     (def jp (script "janet-pm"))
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
              SetReleasedSHA Released RunPeers
              (^connect-peers (log "Demiurge is ready"))])
          (log "Release finished")]))}
    "release"))

(define-spy ReleaseOnSHA
  "Spy that snoops sha and start the release on setting it"
  [&]
  (make-snoop
    @{:snoop
      (fn [_ {:view view} spys]
        (when (view :sha)
          (array/clear spys)
          (^release (os/clock))))}
    "release on sha"))

(define-event PrepareView
  "Prepares view"
  {:update (fn [_ state] (put state :view @{:spawned @{}}))
   :effect (fn [_ {:view view :build-path bp :env env} _]
             (os/cd bp)
             (def jpa (path/abspath (path/join bp env)))
             (os/setenv "JANET_PATH" jpa)
             (os/setenv "PATH"
                        (string (path/join jpa "bin")
                                (if (= (os/which) :windows) ";" ":")
                                (os/getenv "PATH")))
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
            (produce RunPeers (^connect-peers (log "Demiurge is ready"))) :ok)))}))

(define-effect Bootstrap
  "Event that bootstraps the remote site"
  [_ {:host host :env env
      :build-path bp :data-path dp :release-path rp} _]
  (let [url ($<_ git remote get-url origin)
        rbp (path/posix/join "/" ;(butlast (path/parts bp)))
        sbp (path/posix/join rbp "spork")
        conf (os/getenv "CONF" "conf.jdn")]
    (eprint "------------ Ensure paths")
    (exec
      ;(ssh-cmds host
                 [:rm "-rf" bp] [:rm "-rf" rp] [:rm "-rf" sbp]
                 [:mkdir :-p rbp] [:mkdir :-p rp] [:mkdir :-p dp]))
    (eprint "------------ Ensure repositories")
    (exec
      ;(ssh-cmds host
                 [:git :clone "--depth=1" url bp]
                 [:git :clone "--depth=1"
                  "https://github.com/janet-lang/spork" sbp]))
    (eprint "------------ Ensure environment")
    (exec
      ;(ssh-cmds host
                 [:cd bp]
                 ["/usr/local/lib/janet/bin/janet-pm" :full-env env]
                 [". ./prod/bin/activate"]
                 [:janet "--install" sbp]
                 [:janet-pm :install "jhydro"]
                 [:janet-pm :install "https://git.sr.ht/~pepe/gp"]))
    (eprint "------------ Upload configuration")
    (exec "scp" conf (string host ":" bp "/conf.jdn"))
    (eprint "------------ Quickbin demiurge")
    (exec ;(ssh-cmds host
                     [:cd bp] [". ./prod/bin/activate"]
                     [:janet-pm :quickbin "demiurge.janet" "demiurge"]
                     [:mv "demiurge" rp]))
    (eprint "---------- Seed the Tree")
    (exec ;(ssh-cmds host [:cd bp] [". ./prod/bin/activate"]
                     [:janet "bin/seed-tree.janet" "t"]))
    (eprint "------------ Run demiurge")
    (exec ;(ssh-cmds host
                     [:nohup (path/posix/join rp "/demiurge")
                      "> /dev/null 2>&1 &"]))))

(def initial-state
  "Navigation to initial state in config"
  ((=> (=>symbiont-initial-state :demiurge)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(defn main
  ```
  Main entry into demiurge.
  ```
  [_ &opt bootstrap]
  (def events
    (if bootstrap
      [Bootstrap]
      [RPC GetGitSHA PrepareView RunPeers ReleaseOnSHA
       (^connect-peers (log "Demiurge is ready"))]))
  (->
    initial-state
    (make-manager on-error)
    (:transact ;events)
    :await)
  (os/exit 0))
