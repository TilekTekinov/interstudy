(use /environment /schema spork/sh-dsl spork/sh)

(setdyn *rpc-defines* [:view])

(def PeersConnected
  "Event that logs peers connections"
  (log "Peers connected"))

(defn ^save-sha
  "Event that saves git sha"
  [sha]
  (make-update
    (fn [_ {:view view}]
      ((>put :sha sha) view))
    "save sha"))

(define-event SetReleasedSHA
  "Writes the current SHA to file"
  {:update
   (fn [_ {:view view}] (put view :release-sha (view :sha)))
   :effect
   (fn [_ {:view {:sha sha} :release-path rp} _]
     (spit (path/abspath (path/join rp "release.sha")) sha))})

(define-watch PullGetSHA
  "Save in the state the latest shas of the repository"
  [_ {:dry dry} _]
  (producer
    (if-not dry ($< git pull))
    (produce (^save-sha (string ($<_ git rev-parse HEAD))))))

(define-event Released
  "Marks the end of releasing"
  {:update
   (fn [_ {:view view}] ((>put :releasing false) view))
   :watch PullGetSHA})

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
                (:close pc)))}))

(define-event StopPeers
  "Sends stop RPC to all peers"
  {:update (fn [_ {:view view}] (put view :ran false))
   :watch
   (fn [_ state _]
     (def {:dry dry :peers peers :view {:spawned spawned}} state)
     (if (and spawned (not dry))
       (seq [peer :in peers] (^stop-peer peer))))})

(defn ^save-wait-spawned
  "Saves peer's process and waits it for commands"
  [peer proc]
  (make-event
    {:update
     (fn [_ {:view {:spawned spawned}}]
       (put spawned peer proc))
     :watch
     (fn [_ {:entries entries} _]
       (producer
         (def ob @"")
         (os/proc-wait proc)
         (ev/read (proc :out) :all ob)
         (unless (empty? ob)
           (let [[peer arg] (unmarshal ob)
                 [cmd flags] (entries peer)
                 proc (pipe-out [[;cmd arg] flags])]
             (produce
               (^save-wait-spawned peer proc))))))}
    "save and wait for peer"))

(define-event RunPeers
  "Runs peers event"
  {:update
   (fn [_ {:view view}] (put view :ran (os/clock)))
   :watch
   (fn [_ {:dry dry :release-path rp :builder builder
           :entries entries :autostart autostart} _]
     (unless dry
       (producer
         (each peer autostart
           (produce
             (^save-wait-spawned peer
                                 (pipe-out (entries peer)))))
         (produce (^connect-peers PeersConnected)))))})

(defn ^deploy-peer
  "Deploys one peer"
  [peer]
  (make-event
    {:watch (log "Deployed peer " peer)
     :effect
     (fn [_ {:build-path bp :release-path rp} _]
       (def target (path/abspath (path/join rp peer)))
       (protect (os/rm target))
       (copy-file
         (path/abspath (path/join bp "_build/release/" peer))
         target)
       (os/chmod target 8r700))}))

(define-watch Deploy
  "Deploys peers"
  [_ {:entries entries} _]
  (seq [peer :keys entries] (^deploy-peer peer)))

(define-event Build
  "Builds peers"
  {:effect
   (fn [&]
     ($ janet-pm "clean")
     ($ janet-pm "build"))})

(defn ^mark-release
  "Marks that release has started"
  [now]
  (make-update
    (fn [_ {:view view}] ((>put :releasing now) view))
    "mark release"))

(defn ^release
  "Event that releases the new version of the thicket."
  [now]
  (make-watch
    (fn [_ {:release-path rp :dry dry :builder builder
            :view {:sha sha :release-sha rsha :ran ran}} _]
      (if (and rsha (= sha rsha))
        [(log "Latest version is already released") Released]
        [(log "Starting new release")
         ;[;(if (or (not builder) dry)
              [(log "Build dry run") StopPeers]
              [PullGetSHA StopPeers Build Deploy])
           SetReleasedSHA Released Ready
           ;(if ran
              [RunPeers (^connect-peers PeersConnected)]
              [Empty])]
         (log "Release finished")]))
    "release"))

(define-spy ReleaseOnSHA
  "Spy that snoops sha and start the release on setting it"
  [&]
  (make-snoop
    @{:snoop
      (fn [self {:view view :builder builder} spys event]
        (when (view :sha)
          (while (def i (find-index |(= $ self) spys))
            (array/remove spys i))
          (^release (os/clock))))}
    "release on sha"))

(defn ^save-entries
  "Saves code entries for peers"
  [entries]
  (make-update
    (fn [_ state] (put state :entries entries))))

(define-event PrepareView
  "Prepares view"
  {:update (fn [_ state] (put state :view @{:spawned @{}}))
   :watch (fn [_ {:builder builder :peers peers
                  :release-path rp :build-path bp} _]
            (def entries
              ((=> (>Y (??? {first (?eq 'declare-executable)}))
                   (>map |(slice $ 1 -1)))
                (parse-all (slurp (path/join bp "bundle/init.janet")))))
            (def transformer
              (if builder
                (fn [n e] [[(path/join rp (executable n))] :x])
                (fn [n e] [["janet" "-d" e] :p])))
            (^save-entries (tabseq [[_ n _ e] :in entries] (keyword n)
                             (transformer n e))))
   :effect (fn [_ {:view view :build-path bp :env env} _]
             (os/cd bp)
             (def jpa (path/abspath (path/join bp env)))
             (os/setenv "JANET_PATH" jpa)
             (os/setenv "PATH"
                        (string (path/join jpa "bin")
                                (if (= (os/which) :windows) ";" ":")
                                (os/getenv "PATH")))
             (setdyn :view view))})

(defn guard-releasing
  "Guards the rpc runction for the release"
  [handler]
  (fn [& args]
    (define :view)
    (if-let [from (view :releasing)]
      [:busy from (view :sha)]
      (handler ;args))))

(defr +:state
  "RPC function, that reports the state of the demiurge"
  [guard-releasing]
  (if-let [ran (view :ran)
           spwnd ((=> :spawned keys freeze) view)]
    [:running ran spwnd]
    [:idle (view :sha) (view :release-sha)]))

(defr +:release
  "RPC function, that starts the release if possible."
  [guard-releasing]
  (let [now (os/clock)]
    (produce (^mark-release now) ReleaseOnSHA PullGetSHA)
    [:ok now]))

(defr +:stop-peers
  "RPC function, that stops the peers if possible."
  [guard-releasing]
  (if (view :ran)
    (do (produce StopPeers) :ok)
    :not-running))
(defr +:run-peers
  "RPC function, that starts the peers if possible."
  [guard-releasing]
  (if-let [ran (view :ran)]
    [:running ran]
    (do
      (produce RunPeers
               (^connect-peers PeersConnected))

      :ok)))

(defr +:stop
  "RPC function that stops the demiurge."
  []
  (if (view :ran) (produce StopPeers))
  (produce (^delay 0.001 Stop))
  :ok)

(defr +:update-config
  "RPC function that updates the config, if possible."
  []
  (def [new-config] args)
  (spit "conf.jdn" (jdn/render new-config))
  :ok)

(def rpc-funcs
  "RPC functions for the tree"
  @{:state +:state
    :release +:release
    :update-config +:update-config
    :stop-peers +:stop-peers
    :run-peers +:run-peers
    :stop +:stop})

(define-effect Bootstrap
  "Event that bootstraps the remote site"
  [_ {:host host :env env
      :build-path bp :data-path dp :release-path rp
      :bootstrap bootstrap} _]
  (let [url ($<_ git remote get-url origin)
        rbp (path/posix/join "/" ;(butlast (path/parts bp)))
        sbp (path/posix/join rbp "spork")
        conf (jdn/render compile-config)
        activate [". ./prod/bin/activate"]]
    (eprin "------------ Ensure paths")
    (exec
      ;(ssh-cmds host
                 [:rm "-rf" bp] [:rm "-rf" rp] [:rm "-rf" sbp]
                 [:mkdir :-p rbp] [:mkdir :-p rp] [:mkdir :-p dp]))
    (eprint " done")
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
                 activate
                 [:janet "--install" sbp]
                 [:janet-pm :install "jhydro"]
                 [:janet-pm :install "https://git.sr.ht/~pepe/gp"]))
    (eprin "------------ Upload configuration")
    (exec ;(ssh-cmds host
                     [:cd bp]
                     (shlc "cat <<'EOF' > conf.jdn" "\n" conf "\nEOF")))
    (eprint " done")
    (eprint "------------ Quickbin demiurge")
    (exec ;(ssh-cmds host
                     [:cd bp] activate
                     [:janet-pm :quickbin "demiurge.janet" "demiurge"]
                     [:mv "demiurge" rp]))
    (eprint "------------ Quickbin dm")
    (exec ;(ssh-cmds host
                     [:cd bp] activate
                     [:janet-pm :quickbin "bin/dm.janet" "dm"]
                     [:mv "dm" rp]))
    (when (= bootstrap :seed)
      (eprint "---------- Seed the Tree")
      (exec ;(ssh-cmds host
                       [:cd bp] activate
                       [:janet "bin/seed-tree.janet" "t"])))
    (eprint "------------ Run demiurge")
    (exec ;(ssh-cmds host
                     [:nohup
                      (path/posix/join rp "/demiurge") ">>"
                      (path/posix/join dp "/demiurge.log")
                      "2>&1 &"]))))

(def initial-state
  "Navigation to initial state in config"
  ((=> (=>symbiont-initial-state :demiurge)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(defn ^bootstrap-arg
  "Saves the bootstrap argument"
  [arg]
  (make-update
    (fn [_ state] (put state :bootstrap (keyword arg)))))

(defn main
  ```
  Main entry into demiurge.
  ```
  [_ &opt bootstrap]
  (def events
    (if bootstrap
      [(^bootstrap-arg bootstrap) Bootstrap]
      [RPC PullGetSHA PrepareView ReleaseOnSHA Ready]))
  (->
    initial-state
    (make-manager on-error)
    (:transact ;events)
    :await)
  (os/exit 0))
