(use /environment /schema)

(def collections
  "All collections provided by the tree"
  [:faculties :semesters :study-programmes :courses])

(define-update RefreshView
  "Event that refreshes view"
  [_ {:view view :store store}]
  (def active-semester (:load store :active-semester))
  (def active-courses (:transact store :courses (>Y (??? {:active truthy? :semester (?eq active-semester)}))))
  (merge-into view {:active-semester active-semester
                    :active-courses active-courses}))

(defn ^set-active-semester
  "Event that saves active semester into store"
  [semester]
  (make-event
    {:update
     (fn [_ {:store store :view view}]
       (:save store semester :active-semester))
     :watch [Flush RefreshView]}))

(def rpc-funcs
  "RPC functions for the tree"
  (merge-into
    @{:active-semester
      (fn [rpc] (define :view) (view :active-semester))
      :set-active-semester
      (fn [rpc semester]
        (produce (^set-active-semester semester))
        :ok)}
    (tabseq [coll :in (array/concat @[:active-courses] collections)]
      coll (fn [rpc]
             (define :view)
             (view coll)))))

(def initial-state
  "Configuration"
  ((=> (=>machine-initial-state :tree)
       (>update :rpc (update-rpc rpc-funcs))) compile-config))

(define-event PrepareView
  "Initializes view and puts it in the dyn"
  {:update
   (fn [_ state]
     ((>put :view
            (:transact (state :store) (>select-keys ;collections)))
       state))
   :watch RefreshView
   :effect (fn [_ {:view view} _] (setdyn :view view))})

(defn main
  ```
  Main entry into tree.
  ```
  [_]
  (-> initial-state
      (make-manager on-error)
      (:transact PrepareStore PrepareView)
      (:transact RPC)
      :await)
  (os/exit 0))
