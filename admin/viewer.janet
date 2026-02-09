(use ./environment /schema)

(def collections/view
  "View collections"
  [:registrations :enrollments])

(def routes
  "HTTP routes"
  @{"/" (make/index "Viewer")
    "/registrations"
    @{"" /registrations
      "/search" /registrations/search
      "/filter/" /registrations/filter}})

(def rpc-funcs
  "RPC functions"
  @{:refresh (fn [_ & what] (produce (^refresh-view ;what)) :ok)
    :stop close-peers-stop})

(def initial-state
  "Initial state"
  ((=> (=>symbiont-initial-state :viewer)
       (>put :routes routes)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(define-watch Start
  "Starts the machinery"
  [&]
  [(^prepare-view collections/view) (^register :tree) HTTP RPC
    (log "Viewer is ready")])

(defn main
  ```
  Main entry into student symbiont.
  ```
  [_ session]
  (-> initial-state
      (put :session session)
      (make-manager on-error)
      (:transact (^connect-peers Start Exit))
      :await)
  (os/exit 0))
