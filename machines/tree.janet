(use /environment /schema)

(def collections
  "All collections provided by the tree"
  [:faculties :semesters :study-programmes])

(define-update RefreshView
  "Event that refreshes view"
  [_ {:view view :store store}]
  (def c @[])
  (merge-into
    view
    (:transact store
               (<- c (=> :active-semester))
               :courses (<- c)
               (<- c (=> (>Y (??? {:active truthy? :semester (?eq (c 0))}))))
               (>base c)
               (>zipcoll [:active-semester :courses :active-courses]))))

(defn ^set-active-semester
  "Event that saves active semester into store"
  [semester]
  (make-event
    {:update
     (fn [_ {:store store :view view}]
       (:save store semester :active-semester))
     :watch [RefreshView Flush]}))

(defn ^save-course
  "Event that saves course"
  [code new]
  (make-event
    {:update (fn [_ {:store store}]
               (:transact store
                          (=>course/by-code code)
                          (>merge-into new)))
     :watch [RefreshView Flush]}))

(def rpc-funcs
  "RPC functions for the tree"
  (merge-into
    @{:active-semester
      (fn [rpc] (define :view) (view :active-semester))
      :set-active-semester
      (fn [rpc semester]
        (produce (^set-active-semester semester))
        :ok)
      :save-course
      (fn [rpc code new]
        (produce (^save-course code new))
        :ok)}
    (tabseq [coll :in (array/concat @[:active-courses :courses] collections)]
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
